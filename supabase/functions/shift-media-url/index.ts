import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const headers={
  "content-type":"application/json",
  "cache-control":"no-store",
  "access-control-allow-origin":"*",
  "access-control-allow-methods":"POST,OPTIONS",
  "access-control-allow-headers":"authorization,apikey,content-type,x-client-info",
};
const send=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  if(req.method!=="POST")return send(405,{error:"method_not_allowed"});
  const token=req.headers.get("authorization")?.replace(/^Bearer\s+/i,"");
  if(!token)return send(401,{error:"authentication_required"});
  let payload:Record<string,unknown>;
  try{
    payload=await req.json();
    if(!payload || Array.isArray(payload))return send(400,{error:"invalid_request"});
  }catch{return send(400,{error:"invalid_json"});}
  const id=typeof payload.post_id==="string"?payload.post_id:"";
  const version=payload.version_number;
  const purpose=payload.purpose;
  if(!/^[0-9a-f-]{36}$/i.test(id) || !Number.isInteger(version) ||
      (version as number)<1 ||
      !["preview","publishing"].includes(String(purpose))){
    return send(400,{error:"invalid_request"});
  }
  const url=Deno.env.get("SUPABASE_URL");
  const key=Deno.env.get("SUPABASE_ANON_KEY");
  if(!url||!key)return send(503,{error:"backend_not_configured"});
  const client=createClient(url,key,{
    global:{headers:{Authorization:`Bearer ${token}`}},
    auth:{persistSession:false,autoRefreshToken:false},
  });
  const {data:{user},error:authError}=await client.auth.getUser(token);
  if(authError||!user)return send(401,{error:"invalid_session"});
  const {data:post,error:postError}=await client.from("shift_content_posts")
    .select("id,workspace_id,status,current_version,approved_version")
    .eq("id",id).maybeSingle();
  if(postError||!post)return send(404,{error:"post_not_found"});
  const {data:workspace}=await client.from("shift_workspaces").select("id")
    .eq("id",post.workspace_id).eq("owner_id",user.id).maybeSingle();
  if(!workspace)return send(403,{error:"not_authorized"});
  const requested=version as number;
  if(purpose==="publishing" && (post.approved_version!==requested ||
     !["approved","scheduled"].includes(post.status))){
    return send(409,{error:"exact_approved_revision_required"});
  }
  const {data:rev}=await client.from("shift_content_versions").select("media_path")
    .eq("post_id",post.id).eq("version_number",requested).maybeSingle();
  if(!rev?.media_path)return send(404,{error:"media_not_found"});
  const path=rev.media_path as string;
  const expectedPrefix=`${user.id}/${workspace.id}/`;
  if(!path.startsWith(expectedPrefix))return send(403,{error:"media_ownership_failed"});
  const {data:asset}=await client.from("shift_media_assets")
    .select("id,mime_type,size_bytes").eq("workspace_id",workspace.id)
    .eq("storage_path",path).maybeSingle();
  if(!asset||asset.size_bytes>10485760 ||
     !["image/jpeg","image/png","image/webp"].includes(asset.mime_type)){
    return send(415,{error:"unsupported_media"});
  }
  // The bucket stays private. No permanent public URLs are issued.
  const seconds=purpose==="publishing"?900:300;
  const {data:signed,error:storageError}=await client.storage
    .from("shift-media").createSignedUrl(path,seconds);
  if(storageError||!signed?.signedUrl)return send(503,{error:"media_temporarily_unavailable"});
  return send(200,{
    url:signed.signedUrl,
    expires_in_seconds:seconds,
    mime_type:asset.mime_type,
    version_number:requested,
    purpose,
  });
});
