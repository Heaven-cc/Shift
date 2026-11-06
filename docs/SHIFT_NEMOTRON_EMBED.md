# SHIFT: NVIDIA Nemotron 3.5 Embed 1B

Nemotron 3.5 Embed 1B is an **embedding model**, not a chatbot. It converts saved content and queries into vectors for meaning-based search. It does **not** replace Mistral/Kimi for captions, strategy writing or conversation, and cannot by itself resolve Mistral inference timeouts.

## Backend configuration

NVIDIA API reference: https://docs.api.nvidia.com/nim/reference/nvidia-nemotron-3_5-embed-1b-infer

- Model: `nvidia/nemotron-3.5-embed-1b`
- Hosted endpoint: `https://integrate.api.nvidia.com/v1/embeddings`
- Model modes: `input_type: passage` for saved content, `input_type: query` for a search request
- Vector dimensions used in SHIFT: **1024** (model supports 128–2048)
- Uses `encoding_format: float`, `embedding_type: float`, `truncate: END` and `modality: text`

In **SHIFT Supabase → Edge Functions → Secrets** add `SHIFT_NVIDIA_NEMOTRON_EMBED_API_KEY` if you want a separate key. Otherwise, the existing `SHIFT_NVIDIA_API_KEY` is automatically used. There is no need to paste secrets in Flutter or GitHub. No additional endpoint or model ID secret is required for this particular hosted NVIDIA model.

## Workflow

Home → SHIFT AI Workspace → **Nemotron semantic research**:

1. Save research bookmarks or conduct Discover research as usual.
2. Choose **Index saved research** to embed existing saved research titles and summaries. SHIFT indexes only the signed-in workspace's records; up to 32 new/changed sources per operation, up to 60 recent sources available for indexing.
3. Enter a natural-language topic and tap **Semantic search**. SHIFT embeds the query in the correct mode and retrieves up to eight nearby saved source passages using pgvector cosine similarity.
4. Open results at their source URLs. Similarity does not verify factual accuracy.

The index is stored in `public.shift_knowledge_embeddings`, with row-level security enabled and all anonymous/authenticated table permissions revoked. The backend verifies Supabase Auth and workspace ownership. The `shift_match_knowledge` RPC is callable only by the service role. Both indexing and searching use existing per-workspace research rate limits. The model key remains server-side.

This is *on-demand* indexing, not a continuous monitoring worker. New or modified bookmarks require indexing again. The current integration handles text titles/summaries, not page-image embeddings or automatic full-page crawling. Cached embeddings may remain until the next maintenance operation when an original source is removed, so avoid treating the index as authoritative without reviewing the source.

## Verification

Deploy `shift-nemotron` with JWT required. Run Flutter analyzer/test CI. With a signed-in SHIFT user and NVIDIA key, test index, search, returned vector dimensionality, and workspace isolation. Until a live NVIDIA call succeeds, show **configured, not verified**. Keep existing Mistral generation and all TREXVEN services unchanged.
