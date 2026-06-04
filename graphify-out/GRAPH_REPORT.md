# Graph Report - H:\Projects\Akashi\SKILLS_Main_Added\graphify-5  (2026-06-04)

## Corpus Check
- Corpus is ~42,434 words - fits in a single context window. You may not need a graph.

## Summary
- 397 nodes · 678 edges · 14 communities detected
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 99 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_AST Code Extraction|AST Code Extraction]]
- [[_COMMUNITY_Analysis, Reporting & Orchestration|Analysis, Reporting & Orchestration]]
- [[_COMMUNITY_CLI & Platform Installations|CLI & Platform Installations]]
- [[_COMMUNITY_File Detection & Change Watching|File Detection & Change Watching]]
- [[_COMMUNITY_Web Ingest & Security Controls|Web Ingest & Security Controls]]
- [[_COMMUNITY_Cache Management|Cache Management]]
- [[_COMMUNITY_Graph Building & Validation|Graph Building & Validation]]
- [[_COMMUNITY_MCP Stdio Server|MCP Stdio Server]]
- [[_COMMUNITY_Git Hooks Manager|Git Hooks Manager]]
- [[_COMMUNITY_AudioVideo Transcription|Audio/Video Transcription]]
- [[_COMMUNITY_Leiden Community Clustering|Leiden Community Clustering]]
- [[_COMMUNITY_Token Reduction Benchmarking|Token Reduction Benchmarking]]
- [[_COMMUNITY_Wiki Exporter|Wiki Exporter]]
- [[_COMMUNITY_Package Initialization|Package Initialization]]

## God Nodes (most connected - your core abstractions)
1. `main()` - 37 edges
2. `_make_id()` - 29 edges
3. `_rebuild_code()` - 18 edges
4. `_read_text()` - 16 edges
5. `_extract_generic()` - 16 edges
6. `_node_community_map()` - 11 edges
7. `detect()` - 11 edges
8. `to_html()` - 11 edges
9. `extract()` - 11 edges
10. `ingest()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Processing Pipeline` --references--> `build_from_json()`  [INFERRED]
  ARCHITECTURE.md → H:\Projects\Akashi\SKILLS_Main_Added\graphify-5\graphify\build.py
- `Processing Pipeline` --references--> `cluster()`  [INFERRED]
  ARCHITECTURE.md → H:\Projects\Akashi\SKILLS_Main_Added\graphify-5\graphify\cluster.py
- `Processing Pipeline` --references--> `extract()`  [INFERRED]
  ARCHITECTURE.md → H:\Projects\Akashi\SKILLS_Main_Added\graphify-5\graphify\extract.py
- `Processing Pipeline` --references--> `god_nodes()`  [INFERRED]
  ARCHITECTURE.md → H:\Projects\Akashi\SKILLS_Main_Added\graphify-5\graphify\analyze.py
- `Processing Pipeline` --references--> `to_html()`  [INFERRED]
  ARCHITECTURE.md → H:\Projects\Akashi\SKILLS_Main_Added\graphify-5\graphify\export.py

## Communities

### Community 0 - "AST Code Extraction"
Cohesion: 0.04
Nodes (87): _check_tree_sitter_version(), _csharp_extra_walk(), extract(), extract_blade(), extract_c(), extract_cpp(), extract_csharp(), extract_dart() (+79 more)

### Community 1 - "Analysis, Reporting & Orchestration"
Cohesion: 0.05
Nodes (52): _cross_community_surprises(), _cross_file_surprises(), _file_category(), god_nodes(), graph_diff(), _is_concept_node(), _is_file_node(), _node_community_map() (+44 more)

### Community 2 - "CLI & Platform Installations"
Cohesion: 0.06
Nodes (52): _agents_install(), _agents_uninstall(), _antigravity_install(), _antigravity_uninstall(), _check_skill_version(), claude_install(), claude_uninstall(), _clone_repo() (+44 more)

### Community 3 - "File Detection & Change Watching"
Cohesion: 0.07
Nodes (41): classify_file(), convert_office_file(), count_words(), detect(), detect_incremental(), docx_to_markdown(), extract_pdf_text(), FileType (+33 more)

### Community 4 - "Web Ingest & Security Controls"
Cohesion: 0.09
Nodes (35): _detect_url_type(), _download_binary(), _fetch_arxiv(), _fetch_html(), _fetch_tweet(), _fetch_webpage(), _html_to_markdown(), ingest() (+27 more)

### Community 5 - "Cache Management"
Cohesion: 0.16
Nodes (18): _body_content(), cache_dir(), cached_files(), check_semantic_cache(), clear_cache(), file_hash(), load_cached(), Return set of file paths that have a valid cache entry (hash still matches). (+10 more)

### Community 6 - "Graph Building & Validation"
Cohesion: 0.15
Nodes (16): build(), build_from_json(), build_merge(), deduplicate_by_label(), _norm_label(), _normalize_id(), Merge multiple extraction results into one graph.      directed=True produces a, Canonical dedup key — lowercase, alphanumeric only. (+8 more)

### Community 7 - "MCP Stdio Server"
Cohesion: 0.17
Nodes (13): _communities_from_graph(), _filter_blank_stdin(), _find_node(), _load_graph(), Return node IDs whose label or ID matches the search term (diacritic-insensitive, Filter blank lines from stdin before MCP reads it.      Some MCP clients (Claude, Start the MCP server. Requires pip install mcp., Reconstruct community dict from community property stored on nodes. (+5 more)

### Community 8 - "Git Hooks Manager"
Cohesion: 0.21
Nodes (14): _git_root(), _hooks_dir(), install(), _install_hook(), Walk up to find .git directory., Return the git hooks directory, respecting core.hooksPath if set (e.g. Husky)., Install a single git hook, appending if an existing hook is present., Remove graphify section from a git hook using start/end markers. (+6 more)

### Community 9 - "Audio/Video Transcription"
Cohesion: 0.21
Nodes (13): build_whisper_prompt(), download_audio(), _get_whisper(), _get_yt_dlp(), is_url(), _model_name(), Transcribe a video/audio file or URL to a .txt transcript.      If video_path is, Transcribe a list of video/audio files or URLs, return paths to transcript .txt (+5 more)

### Community 10 - "Leiden Community Clustering"
Cohesion: 0.22
Nodes (12): cluster(), cohesion_score(), _partition(), Community detection on NetworkX graphs. Uses Leiden (graspologic) if available,, Run a second Leiden pass on a community subgraph to split it further., Context manager to suppress stdout/stderr during library calls.      graspologic, Ratio of actual intra-community edges to maximum possible., Run community detection. Returns {node_id: community_id}.      Tries Leiden (gra (+4 more)

### Community 11 - "Token Reduction Benchmarking"
Cohesion: 0.28
Nodes (8): _estimate_tokens(), print_benchmark(), _query_subgraph_tokens(), Token-reduction benchmark - measures how much context graphify saves vs naive fu, Print a human-readable benchmark report., Run BFS from best-matching nodes and return estimated tokens in the subgraph con, Measure token reduction: corpus tokens vs graphify query tokens.      Args:, run_benchmark()

### Community 12 - "Wiki Exporter"
Cohesion: 0.36
Nodes (8): _community_article(), _cross_community_links(), _god_node_article(), _index_md(), Return (community_label, edge_count) pairs for cross-community connections, sort, Generate a Wikipedia-style wiki from the graph.      Writes:       - index.md, _safe_filename(), to_wiki()

### Community 13 - "Package Initialization"
Cohesion: 0.67
Nodes (1): graphify - extract · build · cluster · analyze · report.

## Knowledge Gaps
- **164 isolated node(s):** `Graph analysis: god nodes (most connected), surprising connections (cross-commun`, `Invert communities dict: node_id -> community_id.`, `Return True if this node is a file-level hub node (e.g. 'client', 'models')`, `Return the top_n most-connected real entities - the core abstractions.      File`, `Find connections that are genuinely surprising - not obvious from file structure` (+159 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Package Initialization`** (3 nodes): `__getattr__()`, `__init__.py`, `graphify - extract · build · cluster · analyze · report.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `CLI & Platform Installations` to `AST Code Extraction`, `Analysis, Reporting & Orchestration`, `File Detection & Change Watching`, `Graph Building & Validation`, `MCP Stdio Server`, `Leiden Community Clustering`, `Token Reduction Benchmarking`?**
  _High betweenness centrality (0.305) - this node is a cross-community bridge._
- **Why does `_rebuild_code()` connect `File Detection & Change Watching` to `AST Code Extraction`, `Analysis, Reporting & Orchestration`, `CLI & Platform Installations`, `Graph Building & Validation`, `Leiden Community Clustering`?**
  _High betweenness centrality (0.136) - this node is a cross-community bridge._
- **Why does `download_audio()` connect `Audio/Video Transcription` to `AST Code Extraction`, `Web Ingest & Security Controls`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Are the 37 inferred relationships involving `str` (e.g. with `file_hash()` and `to_html()`) actually correct?**
  _`str` has 37 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `main()` (e.g. with `serve()` and `_score_nodes()`) actually correct?**
  _`main()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 13 inferred relationships involving `_rebuild_code()` (e.g. with `detect()` and `extract()`) actually correct?**
  _`_rebuild_code()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Graph analysis: god nodes (most connected), surprising connections (cross-commun`, `Invert communities dict: node_id -> community_id.`, `Return True if this node is a file-level hub node (e.g. 'client', 'models')` to the rest of the system?**
  _164 weakly-connected nodes found - possible documentation gaps or missing edges._