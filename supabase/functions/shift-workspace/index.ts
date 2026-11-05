import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

const env=(k:string)=>Deno.env.get(k)??"";
const headers={
 "Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store",
 "Access-Control-Allow-Origin":"*",
 "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info",
 "Access-Control-Allow-Methods":"POST,OPTIONS"
};
const reply=(obj:unknown,status=200)=>new Response(JSON.stringify(obj),{status,headers});
const admin=()=>createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),
 {auth:{autoRefreshToken:false,persistSession:false}});
const auth=()=>createClient(env("SUPABASE_URL"),env("SUPABASE_ANON_KEY"),
 {auth:{autoRefreshToken:false,persistSession:false}});
const clean=(value:unknown,max=500)=>typeof value==="string"?value.trim().slice(0,max):"";
const record=(v:unknown)=>v&&typeof v==="object"&&!Array.isArray(v)?v as Record<string,unknown>:{};
const white=(v:unknown,names:string[],len=500)=>Object.fromEntries(
 names.map(k=>[k,clean(record(v)[k],len)]));
async function identity(request:Request){
 const token=request.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
 if(!token)throw Error("unauthorized");
 const {data,error}=await auth().auth.getUser(token);
 if(error||!data.user)throw Error("unauthorized");
 const db=admin();
 const {data:workspace,error:wsError}=await db.from("shift_workspaces")
  .select("id").eq("owner_id",data.user.id).single();
 if(wsError||!workspace)throw Error("workspace_not_found");
 return {db,wid:workspace.id as string,uid:data.user.id as string};
}
Deno.serve(async(request)=>{
 try{
  if(request.method==="OPTIONS")return new Response(null,{status:204,headers});
  if(request.method!=="POST")return reply({error:"method_not_allowed"},405);
  const {db,wid,uid}=await identity(request);
  let body:Record<string,unknown>={};
  try{body=record(await request.json())}catch{return reply({error:"invalid_json"},400)}
  const action=body.action;
  if(action==="save_settings"){
   const profile=white(body.profile,["name","language","timezone","avatarCloudPath"]);
   const brand=white(body.brand,["name","description","niche","audience","market",
    "language","tone","topics","blocked","colors","guidelines","logoCloudPath"],2500);
   const prefs=white(body.preferences,["style","length","language","images",
    "categories","avoid","purpose","mode","schedulePreference","days","dailyLimit",
    "weeklyTarget","allowImages","sourceBacked","windowStart","windowEnd",
    "authorizationExpiry","paused"],2000);
   const interests=Array.isArray(body.interests)?body.interests.filter((x:unknown)=>
    typeof x==="string"&&x.length<=80).slice(0,40):[];
   const notifications=Object.fromEntries(Object.entries(record(body.notifications))
     .filter(([k,v])=>k.length<=80&&typeof v==="boolean"));
   if(!brand.name||brand.name.length>120||!profile.timezone||profile.timezone.length>100)
    return reply({error:"invalid_settings"},400);
   for(const [table,key,changes] of [
      ["shift_profiles","user_id",{
        display_name:profile.name,locale:profile.language||"en",
        timezone:profile.timezone,avatar_path:profile.avatarCloudPath||null
      }],
      ["shift_brands","workspace_id",{
        name:brand.name,description:brand.description,audience:brand.audience,
        brand_voice:brand.tone,guidelines:brand.guidelines,
        logo_path:brand.logoCloudPath||null,settings:brand
      }],
      ["shift_preferences","workspace_id",{
        preferences:prefs,interests,notification_preferences:notifications
      }],
      ["shift_workspaces","id",{
        name:brand.name,onboarding_completed:body.onboardingComplete===true,
        timezone:profile.timezone
      }]
    ] as const){
    const value=key==="user_id"?uid:wid;
    const {data,error}=await db.from(table).update(changes).eq(key,value).select(key);
    if(error||!data?.length)throw Error("settings_save_failed");
   }
   return reply({saved:true});
  }
  if(action==="register_media"){
   const path=clean(body.path,600),mime=clean(body.mimeType,60);
   const bytes=Number(body.sizeBytes);
   if(!path.startsWith(uid+"/"+wid+"/")||!["image/jpeg","image/png","image/webp"].includes(mime)||
    !Number.isSafeInteger(bytes)||bytes<1||bytes>10*1024*1024)
    return reply({error:"invalid_media"},400);
   const {data:stored,error:storageError}=await db.schema("storage").from("objects")
    .select("id,name,bucket_id,metadata").eq("bucket_id","shift-media").eq("name",path).maybeSingle();
   if(storageError||!stored)return reply({error:"media_not_uploaded"},409);
   const meta=record(stored.metadata);
   const actualBytes=Number(meta.size??meta.size_bytes??0);
   if(actualBytes!==bytes)return reply({error:"media_size_mismatch"},409);
   const {error}=await db.from("shift_media_assets").upsert({
    workspace_id:wid,storage_path:path,mime_type:mime,size_bytes:bytes,
   },{onConflict:"storage_path"});
   if(error)throw Error("media_record_failed");
   return reply({registered:true});
  }
  if(action==="save_bookmark"){
   const input=record(body.bookmark);
   const clientId=clean(input.client_id,120),url=clean(input.url,2048);
   const topic=clean(input.topic,300),notes=clean(input.notes,5000),publisher=clean(input.publisher,250);
   let uri:URL;
   try{uri=new URL(url)}catch{return reply({error:"invalid_url"},400)}
   if(uri.protocol!=="https:"||uri.username||uri.password||!topic||!clientId)
     return reply({error:"invalid_bookmark"},400);
   const {error}=await db.from("shift_research_bookmarks").upsert({
      workspace_id:wid,client_id:clientId,url:uri.toString(),topic,notes,publisher,
      published_at:input.published_at||null,
    },{onConflict:"workspace_id,client_id"});
   if(error)throw Error("bookmark_save_failed");
   return reply({saved:true});
  }
  if(action==="delete_bookmark"){
   const clientId=clean(body.clientId,120);
   if(!clientId)return reply({error:"invalid_bookmark"},400);
   const {error}=await db.from("shift_research_bookmarks").delete()
      .eq("workspace_id",wid).eq("client_id",clientId);
   if(error)throw Error("bookmark_delete_failed");
   return reply({deleted:true});
  }
  if(action==="delete_draft"){
   const clientId=clean(body.clientId,150);
   if(!clientId)return reply({error:"invalid_draft"},400);
   const {data,error}=await db.from("shift_content_posts").delete()
    .eq("workspace_id",wid).eq("client_id",clientId).eq("status","draft")
    .select("id");
   if(error||!data?.length)return reply({error:"draft_not_deletable"},409);
   return reply({deleted:true});
  }
  return reply({error:"unknown_action"},400);
 }catch(error){
  const message=error instanceof Error?error.message:"internal_error";
  const safe=["unauthorized","workspace_not_found","settings_save_failed","media_record_failed",
    "bookmark_save_failed","bookmark_delete_failed"].includes(message)?message:"request_failed";
  console.error("SHIFT workspace:",safe);
  return reply({error:safe},message==="unauthorized"?401:400);
 }
});
