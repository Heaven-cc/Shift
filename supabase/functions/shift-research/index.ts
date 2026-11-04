import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const headers={
  "content-type":"application/json","cache-control":"no-store",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"authorization,apikey,content-type,x-client-info",
  "access-control-allow-methods":"POST,OPTIONS",
};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
type SearchResult={url:string,title:string,publisher:string,summary:string};
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  if(req.method!=="POST")return reply(405,{error:"method_not_allowed"});
  const searchKey=Deno.env.get("SHIFT_BRAVE_SEARCH_API_KEY");
  if(!searchKey)return reply(503,{error:"research_not_configured",message:"A licensed search provider has not been enabled."});
  const auth=req.headers.get("authorization");
  if(!auth?.startsWith("Bearer "))return reply(401,{error:"sign_in_required"});
  let data:any;
  try{data=await req.json();}catch{return reply(400,{error:"invalid_json"});}
  const query=typeof data.query==="string"?data.query.trim():"";
  const requestId=typeof data.request_id==="string"?data.request_id:"";
  if(query.length<3||query.length>250||!/^\w[\w-]{7,80}$/.test(requestId)){
    return reply(400,{error:"invalid_request"});
  }
  const url=Deno.env.get("SUPABASE_URL");
  const anon=Deno.env.get("SUPABASE_ANON_KEY");
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url||!anon||!service)return reply(503,{error:"backend_not_configured"});
  const caller=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:{user},error}=await caller.auth.getUser(auth.slice(7));
  if(error||!user)return reply(401,{error:"invalid_session"});
  const admin=createClient(url,service,{auth:{persistSession:false}});
  const {data:workspace}=await admin.from("shift_workspaces").select("id").eq("owner_id",user.id).maybeSingle();
  if(!workspace)return reply(403,{error:"workspace_not_found"});
  const {data:existing}=await admin.from("shift_research_jobs")
    .select("id,query,status,result").eq("workspace_id",workspace.id).eq("request_id",requestId).maybeSingle();
  if(existing){
    if(existing.query!==query)return reply(409,{error:"idempotency_conflict"});
    return reply(existing.status==="completed"?200:202,{job_id:existing.id,status:existing.status,results:existing.result});
  }
  const {data:allowed,error:quotaError}=await admin.rpc("shift_ai_allow_request",{
    p_user:user.id,p_workspace:workspace.id,p_category:"research",
  });
  if(quotaError)return reply(503,{error:"quota_service_unavailable"});
  if(allowed!==true)return reply(429,{error:"hourly_search_limit"});
  const {data:job,error:jobError}=await admin.from("shift_research_jobs").insert({
    workspace_id:workspace.id,query,request_id:requestId,status:"running",
  }).select("id").single();
  if(jobError||!job)return reply(503,{error:"research_queue_error"});
  try {
    const destination=new URL("https://api.search.brave.com/res/v1/web/search");
    destination.searchParams.set("q",query);
    destination.searchParams.set("count","8");
    destination.searchParams.set("safesearch","strict");
    const response=await fetch(destination,{
      headers:{"Accept":"application/json","X-Subscription-Token":searchKey},
      signal:AbortSignal.timeout(15000),
    });
    if(!response.ok)throw new Error("search_provider_unavailable");
    const payload=await response.json();
    const results:SearchResult[]=[];
    const seen=new Set<string>();
    for(const item of (payload.web?.results??[])) {
      if(typeof item.url!=="string")continue;
      let link:URL;
      try {link=new URL(item.url);} catch {continue;}
      if(link.protocol!=="https:"||link.username||link.password||
         link.hostname==="localhost"||link.hostname.endsWith(".local")||
         seen.has(link.toString()))continue;
      seen.add(link.toString());
      results.push({
        url:link.toString(),title:String(item.title??"").slice(0,250),
        publisher:link.hostname.slice(0,180),
        summary:String(item.description??"").slice(0,800),
      });
      if(results.length>=8)break;
    }
    const fetchedAt=new Date().toISOString();
    if(results.length){
      const {error:sourceError}=await admin.from("shift_research_sources").insert(
        results.map(item=>({
          workspace_id:workspace.id,research_job_id:job.id,
          url:item.url,title:item.title,publisher:item.publisher,
          summary:item.summary,fetched_at:fetchedAt,verified:false,
        })),
      );
      if(sourceError)throw new Error("source_storage_unavailable");
    }
    await admin.from("shift_research_jobs").update({
      status:"completed",result:{results,provider:"brave",fetched_at:fetchedAt,verified:false},
      completed_at:fetchedAt,
    }).eq("id",job.id);
    return reply(200,{job_id:job.id,results,provider:"brave",fetched_at:fetchedAt,verified:false});
  }catch{
    await admin.from("shift_research_jobs").update({
      status:"failed",error_code:"research_failed",completed_at:new Date().toISOString(),
    }).eq("id",job.id);
    return reply(502,{error:"research_failed",message:"No verified results available. Please retry."});
  }
});
