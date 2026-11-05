import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.78.0";

/**
 * SHIFT Postiz bridge: no SHIFT background worker.
 * Self-hosted Postiz performs scheduling after a manual, approved request.
 * Verify-JWT is disabled at the gateway ONLY because Postiz OAuth callback
 * cannot carry a Supabase bearer token. All other operations verify auth.getUser.
 */
const env = (key: string) => Deno.env.get(key) ?? "";
const supaUrl = env("SUPABASE_URL");
const anonKey = env("SUPABASE_ANON_KEY");
const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
const apiUrl = env("SHIFT_POSTIZ_API_URL").replace(/\/$/, "");
const webUrl = env("SHIFT_POSTIZ_WEB_URL").replace(/\/$/, "");
const callbackUrl = env("SHIFT_POSTIZ_CALLBACK_URL");
const clientId = env("SHIFT_POSTIZ_CLIENT_ID");
const clientSecret = env("SHIFT_POSTIZ_CLIENT_SECRET");
const keyHex = env("SHIFT_POSTIZ_ENCRYPTION_KEY_HEX");
const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
const json = (value: unknown, status=200) => new Response(JSON.stringify(value),{status,headers});
const service = () => createClient(supaUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
const apiBase = () => {
  if (!/^https:\/\/[^/?#]+(?:\/[^?#]*)?\/api\/public\/v1$/.test(apiUrl)) throw Error("Postiz HTTPS public API URL is not configured");
  return apiUrl;
};
const configReady = () => Boolean(supaUrl && anonKey && serviceKey && apiUrl && webUrl && callbackUrl && clientId && clientSecret && /^[0-9a-fA-F]{64}$/.test(keyHex));
const hex = (data: Uint8Array) => Array.from(data,b=>b.toString(16).padStart(2,"0")).join("");
const fromHex = (value: string) => new Uint8Array((value.match(/../g) ?? []).map(s=>parseInt(s,16)));
const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const unb64 = (value: string) => Uint8Array.from(atob(value),c=>c.charCodeAt(0));
async function secretKey() {
  return crypto.subtle.importKey("raw",fromHex(keyHex),"AES-GCM",false,["encrypt","decrypt"]);
}
async function encrypt(token: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const bytes = await crypto.subtle.encrypt({name:"AES-GCM",iv},await secretKey(),new TextEncoder().encode(token));
  return {token_iv:b64(iv),token_ciphertext:b64(new Uint8Array(bytes))};
}
async function decrypt(record: {token_iv:string;token_ciphertext:string}) {
  const value = await crypto.subtle.decrypt({name:"AES-GCM",iv:unb64(record.token_iv)},await secretKey(),unb64(record.token_ciphertext));
  return new TextDecoder().decode(value);
}
async function digest(state: string) {
  const data = new TextEncoder().encode(state);
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256",data)));
}
async function identity(req: Request) {
  const token = req.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) throw Error("unauthorized");
  const auth = createClient(supaUrl,anonKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error} = await auth.auth.getUser(token);
  if(error || !data.user) throw Error("unauthorized");
  const db = service();
  const {data:workspace,error:workspaceError}=await db.from("shift_workspaces").select("id").eq("owner_id",data.user.id).single();
  if(workspaceError || !workspace) throw Error("workspace_not_found");
  return {db,userId:data.user.id,workspaceId:workspace.id as string};
}
async function connection(db:ReturnType<typeof service>, workspaceId:string) {
  const {data,error}=await db.from("shift_postiz_connections")
    .select("token_iv,token_ciphertext").eq("workspace_id",workspaceId).maybeSingle();
  if(error) throw Error("postiz_store_unavailable");
  if(!data) throw Error("postiz_not_connected");
  return decrypt(data);
}
async function postiz(path:string, token:string, init?:RequestInit) {
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(),15000);
  try{
    const res=await fetch(apiBase()+path,{...init,signal:controller.signal,
      headers:{"Authorization":token,"Accept":"application/json",...(init?.body?{"Content-Type":"application/json"}:{})}});
    const body=await res.text();
    let value:unknown;
    try{value=JSON.parse(body)}catch{value=null}
    if(!res.ok) throw Error("postiz_http_"+res.status);
    return value;
  }finally{clearTimeout(timer)}
}
type Channel={id:string;provider:string;name:string};
async function uploadImage(token:string, db:ReturnType<typeof service>, workspaceId:string, storagePath:string) {
  if(storagePath.length>512 || storagePath.startsWith("/") || storagePath.includes("..")) throw Error("invalid_media_path");
  const {data:asset,error}=await db.from("shift_media_assets").select("mime_type,size_bytes")
    .eq("workspace_id",workspaceId).eq("storage_path",storagePath).maybeSingle();
  if(error || !asset || !["image/jpeg","image/png","image/webp"].includes(asset.mime_type) ||
      asset.size_bytes>10*1024*1024) throw Error("invalid_media_asset");
  const {data:blob,error:storageError}=await db.storage.from("shift-media").download(storagePath);
  if(storageError || !blob || blob.size>10*1024*1024) throw Error("invalid_media_asset");
  const extension=asset.mime_type==="image/png"?"png":asset.mime_type==="image/webp"?"webp":"jpg";
  const form=new FormData();
  form.append("file",blob,"shift-upload."+extension);
  const aborter=new AbortController();
  const timer=setTimeout(()=>aborter.abort(),25000);
  try {
    const res=await fetch(apiBase()+"/upload",{method:"POST",
      headers:{Authorization:token,Accept:"application/json"},body:form,signal:aborter.signal});
    if(!res.ok) throw Error("postiz_upload_failed");
    const value=await res.json();
    const file=value && typeof value==="object" ? value as Record<string,unknown> : {};
    const id=typeof file.id==="string"?file.id:"";
    const path=typeof file.path==="string"?file.path:"";
    if(!id || !/^https:\/\//.test(path)) throw Error("postiz_upload_failed");
    return {id,path};
  } finally {clearTimeout(timer)}
}
async function channels(token:string):Promise<Channel[]> {
  const data=await postiz("/integrations",token);
  const raw=Array.isArray(data)?data:(data && typeof data==="object" ?
    ((data as Record<string,unknown>).integrations ?? (data as Record<string,unknown>).items ?? []):[]);
  if(!Array.isArray(raw)) return [];
  return raw.flatMap((item:unknown)=>{
    if(!item||typeof item!=="object")return [];
    const x=item as Record<string,unknown>;
    const id=String(x.id??"");const provider=String(x.providerIdentifier??x.provider??"");
    if(!id||!provider)return [];
    return [{id,provider,name:String(x.name??x.displayName??x.identifier??provider).slice(0,200)}];
  });
}
async function callback(req:Request):Promise<Response> {
  const url=new URL(req.url);
  const state=url.searchParams.get("state")??"";
  const code=url.searchParams.get("code")??"";
  if(!/^[0-9a-f]{64}$/.test(state)||!code||code.length>4096) return json({error:"invalid_oauth_callback"},400);
  const db=service();
  const {data:attempt,error}=await db.from("shift_postiz_oauth_states").select("*")
    .eq("state_hash",await digest(state)).is("consumed_at",null).gt("expires_at",new Date().toISOString()).maybeSingle();
  if(error||!attempt)return json({error:"oauth_state_expired_or_used"},400);
  const {data:consumed,error:useError}=await db.from("shift_postiz_oauth_states")
    .update({consumed_at:new Date().toISOString()}).eq("id",attempt.id).is("consumed_at",null).select("id");
  if(useError||!consumed?.length)return json({error:"oauth_state_used"},400);
  const endpoint=apiBase().replace(/\/public\/v1$/,"/oauth/token");
  const response=await fetch(endpoint,{method:"POST",headers:{"content-type":"application/json"},
    body:JSON.stringify({grant_type:"authorization_code",code,client_id:clientId,client_secret:clientSecret})});
  if(!response.ok)return json({error:"oauth_exchange_failed",status:response.status},502);
  const tokenData=await response.json();
  const token=tokenData.access_token;
  if(typeof token!=="string"||!token.startsWith("pos_"))return json({error:"oauth_invalid_token"},502);
  const cipher=await encrypt(token);
  const {error:saveError}=await db.from("shift_postiz_connections").upsert({
    workspace_id:attempt.workspace_id,...cipher,organization_id:tokenData.id??null,connected_at:new Date().toISOString()
  },{onConflict:"workspace_id"});
  if(saveError)throw Error("postiz_store_unavailable");
  // Only a success message; never place the token in a redirect or frontend.
  return new Response("<!doctype html><html><body><h2>Postiz connected to SHIFT</h2><p>Return to SHIFT and refresh Social Accounts.</p></body></html>",
    {headers:{"Content-Type":"text/html; charset=utf-8","Cache-Control":"no-store","X-Content-Type-Options":"nosniff"}});
}
async function handler(req:Request):Promise<Response> {
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  if(req.method==="GET" && new URL(req.url).searchParams.get("action")==="callback") {
    if(!configReady())return json({error:"postiz_not_configured"},503);
    return callback(req);
  }
  if(req.method!=="POST")return json({error:"method_not_allowed"},405);
  if(!configReady())return json({error:"postiz_not_configured"},503);
  const {db,userId,workspaceId}=await identity(req);
  let body:Record<string,unknown>={};
  try{body=await req.json()}catch{return json({error:"invalid_json"},400)}
  const action=body.action;
  if(action==="status") {
    const {data}=await db.from("shift_postiz_connections").select("workspace_id").eq("workspace_id",workspaceId).maybeSingle();
    return json({connected:Boolean(data),scheduler:"postiz",shiftCloudWorker:"paused"});
  }
  if(action==="connect") {
    const state=hex(crypto.getRandomValues(new Uint8Array(32)));
    const {error}=await db.from("shift_postiz_oauth_states").insert({
      workspace_id:workspaceId,user_id:userId,state_hash:await digest(state),
      expires_at:new Date(Date.now()+10*60*1000).toISOString()
    });
    if(error)throw Error("oauth_state_store_failed");
    const link=new URL("/oauth/authorize",webUrl);
    link.searchParams.set("client_id",clientId);
    link.searchParams.set("response_type","code");
    link.searchParams.set("state",state);
    return json({authorizationUrl:link.toString(),callbackUrl});
  }
  if(action==="disconnect") {
    const {error}=await db.from("shift_postiz_connections").delete().eq("workspace_id",workspaceId);
    if(error)throw Error("disconnect_failed");
    return json({disconnected:true,notice:"Revoke SHIFT access in Postiz Approved Apps as well."});
  }
  const token=await connection(db,workspaceId);
  if(action==="accounts")return json({accounts:await channels(token)});
  if(action==="schedules") {
    const {data,error}=await db.from("shift_postiz_schedules")
      .select("id,post_id,version_number,account_id,provider,scheduled_for,status,remote_ref,created_at")
      .eq("workspace_id",workspaceId).order("created_at",{ascending:false}).limit(100);
    if(error)throw Error("schedule_list_failed");
    return json({schedules:data});
  }
  if(action==="schedule") {
    const postId=body.postId,accountId=body.accountId,at=body.scheduledAt;
    if(typeof postId!=="string"||!/^[0-9a-f-]{36}$/i.test(postId)||typeof accountId!=="string"||
      accountId.length>256||typeof at!=="string")return json({error:"invalid_schedule_request"},400);
    const timestamp=new Date(at);
    if(!Number.isFinite(timestamp.getTime())||timestamp.getTime()<Date.now()+60_000 ||
      timestamp.getTime()>Date.now()+365*86400_000)return json({error:"invalid_schedule_time"},400);
    const {data:post,error:pError}=await db.from("shift_content_posts")
      .select("id,status,current_version,approved_version,workspace_id")
      .eq("id",postId).eq("workspace_id",workspaceId).single();
    if(pError||!post||post.status!=="approved"||post.approved_version!==post.current_version||
      post.current_version<1)return json({error:"approved_version_required"},409);
    const {data:version,error:vError}=await db.from("shift_content_versions")
      .select("caption,headline,hashtags,media_path,platform").eq("post_id",postId)
      .eq("version_number",post.approved_version).single();
    if(vError||!version)return json({error:"approved_content_missing"},409);

    const available=await channels(token);
    const chosen=available.find(c=>c.id===accountId);
    if(!chosen)return json({error:"account_not_connected"},403);
    const supported=["instagram","instagram-standalone","x","linkedin","linkedin-page","facebook","threads","bluesky"];
    if(!supported.includes(chosen.provider))return json({error:"platform_requires_media_or_specific_settings"},422);
    if(["instagram","instagram-standalone"].includes(chosen.provider) && !version.media_path)
      return json({error:"instagram_image_required"},422);
    const normalized=chosen.provider==="linkedin-page"?"linkedin":chosen.provider==="instagram-standalone"?"instagram":chosen.provider;
    const matching=String(version.platform).toLowerCase();
    if(matching!==normalized)return json({error:"draft_destination_mismatch"},409);
    const text=[version.headline,version.caption,version.hashtags].filter(Boolean).join("\n\n").trim();
    if(!text||text.length>5000)return json({error:"invalid_caption_length"},422);
    const {data:job,error:insertError}=await db.from("shift_postiz_schedules").insert({
      workspace_id:workspaceId,post_id:postId,version_number:post.approved_version,
      account_id:accountId,provider:normalized,scheduled_for:timestamp.toISOString()
    }).select("id").single();
    if(insertError)return json({error:insertError.code==="23505"?"already_submitted":"schedule_save_failed"},409);
    const settings:Record<string,unknown>={"__type":chosen.provider};
    if(chosen.provider==="x")settings.who_can_reply_post="everyone";
    if(["instagram","instagram-standalone"].includes(chosen.provider))settings.post_type="post";
    try {
      const media=typeof version.media_path==="string" && version.media_path
        ?[await uploadImage(token,db,workspaceId,version.media_path)]:[];
      const payload={type:"schedule",date:timestamp.toISOString(),shortLink:false,tags:[],
        posts:[{integration:{id:accountId},value:[{content:text,image:media}],settings}]};
      const result=await postiz("/posts",token,{method:"POST",body:JSON.stringify(payload)});
      const rows=Array.isArray(result)?result:(result&&typeof result==="object"?
        ((result as Record<string,unknown>).posts ?? [result]):[]);
      const first=Array.isArray(rows)?rows[0]:null;
      const remoteId=first&&typeof first==="object"?String((first as Record<string,unknown>).id??""):"";
      // Never guess a provider post ID or resend after an ambiguous response.
      const outcome=remoteId?"scheduled":"unknown";
      await db.from("shift_postiz_schedules").update({
        status:outcome,remote_ref:remoteId||null,updated_at:new Date().toISOString()
      }).eq("id",job.id);
      return json({id:job.id,status:outcome,remoteId:remoteId||null});
    } catch(error) {
      await db.from("shift_postiz_schedules").update({
        status:"unknown",error_code:"postiz_submission_uncertain",updated_at:new Date().toISOString()
      }).eq("id",job.id);
      return json({id:job.id,status:"unknown",notice:"Check the Postiz dashboard before retrying. The request might have succeeded."},202);
    }
  }
  return json({error:"unknown_action"},400);
}
Deno.serve(async req=>{
  try{return await handler(req)}
  catch(error){const message=error instanceof Error?error.message:"unexpected_error";
    const status=message==="unauthorized"?401:message==="postiz_not_connected"?409:message==="postiz_http_429"?429:400;
    const safe=["unauthorized","workspace_not_found","postiz_not_connected","postiz_store_unavailable",
      "oauth_state_store_failed","disconnect_failed","postiz_http_401","postiz_http_403","postiz_http_429"].includes(message)
      ?message:"postiz_request_failed";
    console.error("SHIFT Postiz request failed:",safe);
    return json({error:safe},status)
  }
});
