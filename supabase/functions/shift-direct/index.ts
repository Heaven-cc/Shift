import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

const env = (k:string) => Deno.env.get(k) ?? "";
const db = () => createClient(env("SUPABASE_URL"),env("SUPABASE_SERVICE_ROLE_KEY"),{
  auth:{persistSession:false,autoRefreshToken:false}
});
const userClient=()=>createClient(env("SUPABASE_URL"),env("SUPABASE_ANON_KEY"),{
  auth:{persistSession:false,autoRefreshToken:false}
});
const headers={
  "Content-Type":"application/json; charset=utf-8",
  "Cache-Control":"no-store",
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info,x-shift-dispatch-token",
  "Access-Control-Allow-Methods":"POST,OPTIONS"
};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
const allowed=new Set(["bluesky"]);
const bsky="https://bsky.social/xrpc/";
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function fail(code:string):never{throw new Error(code)}
async function request(method:string,route:string,body:unknown,token?:string) {
 const controller=new AbortController();
 const timer=setTimeout(()=>controller.abort(),14000);
 try{
  const res=await fetch(bsky+route,{method,headers:{
   "Content-Type":"application/json",...(token?{"Authorization":"Bearer "+token}:{})
  },body:JSON.stringify(body),signal:controller.signal});
  if(!res.ok){if(res.status===401||res.status===403)fail("provider_unauthorized");
   if(res.status===429)fail("provider_rate_limited");fail("provider_error")}
  return await res.json() as Record<string,unknown>;
 }finally{clearTimeout(timer)}
}
async function session(handle:string,password:string){
 const x=await request("POST","com.atproto.server.createSession",{identifier:handle,password});
 const did=String(x.did??""),jwt=String(x.accessJwt??"");
 if(!did.startsWith("did:")||!jwt)fail("provider_invalid_session");
 return {did,jwt};
}
async function identity(req:Request) {
 const bearer=req.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
 if(!bearer) fail("unauthorized");
 const {data,error}=await userClient().auth.getUser(bearer);
 if(error||!data.user)fail("unauthorized");
 const supa=db();
 const {data:workspace,error:widError}=await supa.from("shift_workspaces")
 .select("id").eq("owner_id",data.user.id).single();
 if(widError||!workspace)fail("workspace_not_found");
 return {supa,wid:workspace.id as string};
}
async function callRpc<T>(supa:ReturnType<typeof db>,fn:string,params:Record<string,unknown>):Promise<T>{
 const {data,error}=await supa.rpc(fn,params);
 if(error)fail("storage_error");
 return data as T;
}
async function dispatch(req:Request) {
 const token=req.headers.get("x-shift-dispatch-token")??"";
 if(!/^[0-9a-f]{64}$/.test(token))return reply({error:"unauthorized"},401);
 const supa=db();
 const okay=await callRpc<boolean>(supa,"shift_verify_direct_dispatch",{p_token:token});
 if(!okay)return reply({error:"unauthorized"},401);
 const ids=await callRpc<Array<{job_id:string}>>(supa,"shift_claim_direct_due",{p_limit:5});
 let published=0,unknown=0,failed=0;
 for(const row of ids??[]) {
  const id=row.job_id;
  const {data:job,error}=await supa.from("shift_direct_jobs")
    .select("id,workspace_id,post_id,version_number,account_id").eq("id",id).single();
  if(error||!job)continue;
  const {data:account}=await supa.from("shift_direct_accounts").select("id,handle,did,state,workspace_id")
   .eq("id",job.account_id).eq("workspace_id",job.workspace_id).single();
  const {data:post}=await supa.from("shift_content_posts")
   .select("status,current_version,approved_version").eq("id",job.post_id).eq("workspace_id",job.workspace_id).single();
  const {data:version}=await supa.from("shift_content_versions")
   .select("caption,headline,hashtags,platform,media_path").eq("post_id",job.post_id)
   .eq("version_number",job.version_number).single();
  if(!account||account.state!=="connected"||!post||
     post.current_version!==job.version_number||post.approved_version!==job.version_number||
     !["approved","scheduled"].includes(post.status)||!version||version.platform!=="Bluesky"||
     version.media_path) {
    await supa.from("shift_direct_jobs").update({state:"failed",error_code:"revalidation_failed",finished_at:new Date().toISOString()}).eq("id",id);
    failed++;continue;
  }
  const password=await callRpc<string>(supa,"shift_get_direct_secret",{p_id:account.id});
  if(!password) {
   await supa.from("shift_direct_jobs").update({state:"failed",error_code:"credential_unavailable",finished_at:new Date().toISOString()}).eq("id",id);
   failed++;continue;
  }
  const content=[version.headline,version.caption,version.hashtags].filter(Boolean).join("\n\n");
  const encoder=new TextEncoder();
  if(encoder.encode(content).length>300 || !content.trim()) {
   await supa.from("shift_direct_jobs").update({state:"failed",error_code:"bluesky_text_limit",finished_at:new Date().toISOString()}).eq("id",id);
   failed++;continue;
  }
  // Set unknown BEFORE submitting to the provider. Never retry blindly:
  // a network timeout after createRecord might mean the post was published.
  await supa.from("shift_direct_jobs").update({state:"unknown",error_code:"provider_outcome_unconfirmed"}).eq("id",id);
  try{
   const auth=await session(account.handle,password);
   if(auth.did!==account.did)fail("identity_changed");
   const postRecord={
     $type:"app.bsky.feed.post",
     text:content,createdAt:new Date().toISOString()
   };
   const result=await request("POST","com.atproto.repo.createRecord",{
    repo:auth.did,collection:"app.bsky.feed.post",record:postRecord,
    // Stable record key makes repeated operator troubleshooting easier;
    // the worker itself never automatically retries this job.
   },auth.jwt);
   const uri=String(result.uri??"");
   if(!uri.startsWith("at://"))fail("missing_confirmation");
   await supa.from("shift_direct_jobs").update({state:"published",remote_uri:uri,error_code:null,
    finished_at:new Date().toISOString()}).eq("id",id);
   // Record per-destination delivery on the job. Do not mutate the shared post
   // status here: the same approved revision may have other pending destinations.
   published++;
  }catch(err){
   const code=err instanceof Error?err.message:"provider_unavailable";
   const safe=["provider_unauthorized","provider_rate_limited","provider_error","identity_changed","missing_confirmation"].includes(code)?code:"provider_outcome_unconfirmed";
   await supa.from("shift_direct_jobs").update({state:"unknown",error_code:safe,finished_at:new Date().toISOString()}).eq("id",id);
   unknown++;
  }
 }
 return reply({claimed:ids?.length??0,published,unknown,failed});
}
async function handle(req:Request):Promise<Response> {
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
 if(req.method!=="POST")return reply({error:"method_not_allowed"},405);
 let body:Record<string,unknown>;
 try{body=await req.json()}catch{return reply({error:"invalid_json"},400)}
 const action=body.action;
 if(action==="dispatch")return dispatch(req);
 const {supa,wid}=await identity(req);
 if(action==="status")return reply({activeProvider:"supabase_cron",postizPreserved:true});
 if(action==="accounts") {
  const {data,error}=await supa.from("shift_direct_accounts")
   .select("id,platform,handle,did,connected_at").eq("workspace_id",wid)
   .eq("state","connected").order("connected_at",{ascending:false});
  if(error)fail("storage_error");
  return reply({accounts:data??[]});
 }
 if(action==="connect_bluesky"){
  const handle=body.handle,password=body.appPassword;
  if(typeof handle!=="string"|| !/^[a-z0-9][a-z0-9.-]{2,253}$/i.test(handle)||
    typeof password!=="string"||password.length<8||password.length>200)return reply({error:"invalid_credentials"},400);
  const verified=await session(handle,password);
  await callRpc<string>(supa,"shift_save_direct_account",{
    p_workspace:wid,p_handle:handle,p_did:verified.did,p_app_password:password
  });
  return reply({connected:true,handle,did:verified.did});
 }
 if(action==="disconnect"){
  const id=body.accountId;
  if(typeof id!=="string"||!uuid.test(id))return reply({error:"invalid_account"},400);
  await callRpc(supa,"shift_disconnect_direct_account",{p_id:id,p_workspace:wid});
  return reply({disconnected:true});
 }
 if(action==="schedule"){
  const postId=body.postId,accountId=body.accountId,at=body.scheduledAt;
  if(typeof postId!=="string"||!uuid.test(postId)||typeof accountId!=="string"||!uuid.test(accountId)||
     typeof at!=="string")return reply({error:"invalid_schedule"},400);
  const time=Date.parse(at);
  if(!Number.isFinite(time)||time<Date.now()+60000||time>Date.now()+365*86400000)
   return reply({error:"invalid_schedule_time"},400);
  const {data:post}=await supa.from("shift_content_posts")
    .select("id,current_version,approved_version,status").eq("id",postId).eq("workspace_id",wid).single();
  if(!post||post.status!=="approved"||post.current_version<1||post.current_version!==post.approved_version)
   return reply({error:"approved_version_required"},409);
  const {data:version}=await supa.from("shift_content_versions")
    .select("caption,headline,hashtags,platform,media_path").eq("post_id",postId)
    .eq("version_number",post.approved_version).single();
  if(!version||version.platform!=="Bluesky"||version.media_path)
   return reply({error:"unsupported_platform_or_media"},422);
  const content=[version.headline,version.caption,version.hashtags].filter(Boolean).join("\n\n");
  if(new TextEncoder().encode(content).length>300)return reply({error:"bluesky_text_limit"},422);
  const {data:account}=await supa.from("shift_direct_accounts").select("id")
    .eq("id",accountId).eq("workspace_id",wid).eq("platform","bluesky").eq("state","connected").single();
  if(!account)return reply({error:"account_not_connected"},403);
  const {data:policy}=await supa.from("shift_automation_policies").select("daily_limit").eq("workspace_id",wid).single();
  const start=new Date(time).toISOString().slice(0,10);
  const startTime=new Date(start+"T00:00:00Z").toISOString();
  const endTime=new Date(Date.parse(startTime)+86400000).toISOString();
  const {count}=await supa.from("shift_direct_jobs").select("id",{count:"exact",head:true})
   .eq("account_id",accountId).gte("scheduled_for",startTime).lt("scheduled_for",endTime)
   .in("state",["queued","processing","published","unknown"]);
  if((count??0)>=(policy?.daily_limit??1))return reply({error:"daily_limit_reached"},409);
  const {data:job,error}=await supa.from("shift_direct_jobs").insert({
    workspace_id:wid,post_id:postId,version_number:post.approved_version,
    account_id:accountId,scheduled_for:new Date(time).toISOString()
  }).select("id,state,scheduled_for").single();
  if(error)return reply({error:error.code==="23505"?"already_scheduled":"schedule_save_failed"},409);
  return reply({job});
 }
 if(action==="jobs"){
  const {data,error}=await supa.from("shift_direct_jobs").select("id,post_id,scheduled_for,state,remote_uri,error_code,account_id")
   .eq("workspace_id",wid).order("scheduled_for",{ascending:false}).limit(100);
  if(error)fail("storage_error");
  const postIds=[...new Set((data??[]).map((j)=>j.post_id as string))];
  const accountIds=[...new Set((data??[]).map((j)=>j.account_id as string))];
  const {data:posts}=postIds.length
    ?await supa.from("shift_content_posts").select("id,title,client_id").eq("workspace_id",wid).in("id",postIds)
    :{data:[]};
  const {data:accounts}=accountIds.length
    ?await supa.from("shift_direct_accounts").select("id,handle,platform").eq("workspace_id",wid).in("id",accountIds)
    :{data:[]};
  const postMap=new Map((posts??[]).map((p)=>[p.id,p]));
  const accountMap=new Map((accounts??[]).map((a)=>[a.id,a]));
  return reply({jobs:(data??[]).map(j=>({
    ...j,title:postMap.get(j.post_id)?.title??'Untitled post',
    clientId:postMap.get(j.post_id)?.client_id??null,
    platform:accountMap.get(j.account_id)?.platform??'bluesky',
    accountHandle:accountMap.get(j.account_id)?.handle??'Unknown account',
  }))});
 }
 if(action==="reschedule"){
  const id=body.jobId,at=body.scheduledAt;
  if(typeof id!=="string"||!uuid.test(id)||typeof at!=="string")return reply({error:"invalid_job"},400);
  const stamp=Date.parse(at);
  if(!Number.isFinite(stamp)||stamp<Date.now()+60000||stamp>Date.now()+365*86400000)
    return reply({error:"invalid_schedule_time"},400);
  const {data:existing}=await supa.from("shift_direct_jobs")
    .select("id,account_id,state").eq("id",id).eq("workspace_id",wid).single();
  if(!existing||existing.state!=="queued")return reply({error:"not_reschedulable"},409);
  const {data:policy}=await supa.from("shift_automation_policies").select("daily_limit").eq("workspace_id",wid).single();
  const day=new Date(stamp).toISOString().substring(0,10);
  const from=day+"T00:00:00.000Z";
  const to=new Date(Date.parse(from)+86400000).toISOString();
  const {count}=await supa.from("shift_direct_jobs").select("id",{count:"exact",head:true})
    .eq("account_id",existing.account_id).neq("id",id)
    .gte("scheduled_for",from).lt("scheduled_for",to)
    .in("state",["queued","processing","published","unknown"]);
  if((count??0)>=(policy?.daily_limit??1))return reply({error:"daily_limit_reached"},409);
  const {data:updated,error:updateError}=await supa.from("shift_direct_jobs")
    .update({scheduled_for:new Date(stamp).toISOString()}).eq("id",id).eq("workspace_id",wid)
    .eq("state","queued").select("id,scheduled_for");
  if(updateError||!updated?.length)return reply({error:"not_reschedulable"},409);
  return reply({job:updated[0]});
 }
 if(action==="cancel"){
  const id=body.jobId;
  if(typeof id!=="string"||!uuid.test(id))return reply({error:"invalid_job"},400);
  const {data,error}=await supa.from("shift_direct_jobs").update({state:"canceled"})
   .eq("id",id).eq("workspace_id",wid).eq("state","queued").select("id");
  if(error||!data?.length)return reply({error:"not_cancellable"},409);
  return reply({canceled:true});
 }
 return reply({error:"unknown_action"},400);
}
Deno.serve(async req=>{
 try{return await handle(req)}
 catch(e){
  const code=e instanceof Error?e.message:"internal_error";
  const allowed=new Set(["unauthorized","workspace_not_found","storage_error","provider_unauthorized",
   "provider_rate_limited","provider_error","provider_invalid_session"]);
  const safe=allowed.has(code)?code:"request_failed";
  console.error("SHIFT direct:",safe);
  return reply({error:safe},code==="unauthorized"?401:code==="provider_unauthorized"?403:400)
 }
});
