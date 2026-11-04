import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const jsonHeaders={
  "content-type":"application/json",
  "cache-control":"no-store",
  "access-control-allow-origin":"*",
  "access-control-allow-headers":"authorization,apikey,content-type,x-client-info",
  "access-control-allow-methods":"POST,OPTIONS",
};
const reply=(status:number,data:unknown)=>new Response(JSON.stringify(data),{status,headers:jsonHeaders});
type RequestPayload={request_key?:unknown;prompt?:unknown};
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:jsonHeaders});
  if(req.method!=="POST")return reply(405,{error:"method_not_allowed"});
  const provider=Deno.env.get("SHIFT_TEXT_PROVIDER")??"";
  const apiKey=Deno.env.get("SHIFT_TEXT_API_KEY")??"";
  const model=Deno.env.get("SHIFT_TEXT_MODEL")??"";
  const endpoints:Record<string,string>={
    groq:"https://api.groq.com/openai/v1/chat/completions",
    openai:"https://api.openai.com/v1/chat/completions",
  };
  if(!apiKey||!model||!endpoints[provider]){
    return reply(503,{error:"ai_provider_not_configured",message:"AI generation is not enabled on this SHIFT project."});
  }
  const auth=req.headers.get("authorization");
  if(!auth?.startsWith("Bearer "))return reply(401,{error:"sign_in_required"});
  let body:RequestPayload;
  try{body=await req.json() as RequestPayload;}catch{return reply(400,{error:"invalid_json"});}
  const prompt=typeof body.prompt==="string"?body.prompt.trim():"";
  const key=typeof body.request_key==="string"?body.request_key:"";
  if(prompt.length<5||prompt.length>4000||key.length<8||key.length>150){
    return reply(400,{error:"invalid_request"});
  }
  const url=Deno.env.get("SUPABASE_URL");
  const anon=Deno.env.get("SUPABASE_ANON_KEY");
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url||!anon||!service)return reply(503,{error:"backend_not_configured"});
  const asUser=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:{user},error:userError}=await asUser.auth.getUser(auth.slice(7));
  if(userError||!user)return reply(401,{error:"invalid_session"});
  const admin=createClient(url,service,{auth:{persistSession:false}});
  const {data:workspace}=await admin.from("shift_workspaces").select("id").eq("owner_id",user.id).maybeSingle();
  if(!workspace)return reply(403,{error:"workspace_not_found"});
  const {data:jobId,error:jobError}=await asUser.rpc("shift_request_text_generation",{
    p_request_key:key,p_prompt:prompt,
  });
  if(jobError)return reply(jobError.code==="53300"?429:400,{error:"request_rejected",message:jobError.message});
  const {data:job,error:loadError}=await admin.from("shift_generation_jobs").select("id,workspace_id,status,result,prompt")
    .eq("id",jobId).eq("workspace_id",workspace.id).maybeSingle();
  if(loadError||!job||job.prompt!==prompt)return reply(409,{error:"idempotency_conflict"});
  if(job.status==="completed")return reply(200,{job_id:job.id,output:job.result,replayed:true});
  const {data:claimed,error:claimError}=await admin.from("shift_generation_jobs")
    .update({status:"running"})
    .eq("id",job.id).eq("status","pending").select("id").maybeSingle();
  if(claimError)return reply(503,{error:"queue_error"});
  if(!claimed)return reply(202,{job_id:job.id,status:job.status});
  const systemPrompt=[
    "You are SHIFT, an original social media writing assistant.",
    "Return valid JSON only with keys caption, hook, hashtags (array of strings), cta, alternative_angles (array of strings).",
    "Do not invent citations, metrics, client testimonials or claims of access to a user's social accounts.",
    "If the user requests unlawful fraud, impersonation or deceptive claims, do not generate promotional material for it.",
    "Stay within the user's topic and produce an editable draft; never publish or claim to have published.",
  ].join(" ");
  try{
    const providerResponse=await fetch(endpoints[provider],{
      method:"POST",headers:{"Authorization":`Bearer ${apiKey}`,"content-type":"application/json"},
      body:JSON.stringify({model,temperature:0.65,max_tokens:1100,
        messages:[{role:"system",content:systemPrompt},{role:"user",content:prompt}]}),
      signal:AbortSignal.timeout(25000),
    });
    if(!providerResponse.ok)throw new Error("provider_unavailable");
    const raw=await providerResponse.json();
    const output=raw?.choices?.[0]?.message?.content;
    if(typeof output!=="string"||output.length>22000)throw new Error("provider_response_invalid");
    const cleaned=output.trim().replace(/^\`\`\`(?:json)?\s*/i,"").replace(/\s*\`\`\`$/,"");
    const parsed=JSON.parse(cleaned);
    if(typeof parsed.caption!=="string"||typeof parsed.hook!=="string"||
       !Array.isArray(parsed.hashtags)||!Array.isArray(parsed.alternative_angles))throw new Error("response_invalid");
    const result={
      caption:parsed.caption.slice(0,12000),
      hook:parsed.hook.slice(0,1000),
      hashtags:parsed.hashtags.filter((x:unknown)=>typeof x==="string").slice(0,30),
      cta:typeof parsed.cta==="string"?parsed.cta.slice(0,1000):"",
      alternative_angles:parsed.alternative_angles.filter((x:unknown)=>typeof x==="string").slice(0,5),
      provider,model,
    };
    await admin.from("shift_generation_jobs").update({
      status:"completed",result,completed_at:new Date().toISOString(),
    }).eq("id",job.id).eq("status","running");
    return reply(200,{job_id:job.id,output:result,replayed:false});
  }catch(e){
    await admin.from("shift_generation_jobs").update({
      status:"failed",error_code:e instanceof Error?e.message.slice(0,60):"generation_failed",
      completed_at:new Date().toISOString(),
    }).eq("id",job.id).eq("status","running");
    return reply(502,{error:"generation_failed",message:"No draft was changed. Retry later."});
  }
});
