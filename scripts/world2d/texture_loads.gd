class_name TextureLoads
extends RefCounted
## Background loads of textures (character sheets, area art) behind a fade or ahead of a citizen's arrival: the one way the game
## starts a threaded resource load (the area section's source lint holds every script to it).
##
## With a real renderer the load runs on the ResourceLoader's worker threads, as ResourceLoader.load_threaded_request does: the
## Compatibility renderer's texture owner is thread-safe and the GPU upload is queued for the main thread.
## The DUMMY renderer of headless runs is not: its texture RID owner has no lock, so a CompressedTexture2D finished on a loader
## thread allocates its RID there while the main thread allocates and frees others. The RID can come out invalid, and the
## texture_2d_initialize queued with it then fails when the main thread next flushes the rendering server's queue (engine error
## `texture_2d_initialize(): Parameter "t" is null`, blamed on whatever script line made that rendering call, e.g. the canopy
## frame's _tint in city_map) and leaks the RID at exit. A dummy renderer has no upload to hide, so there request() starts nothing
## and take() loads the resource on the main thread.
##
## Usage mirrors ResourceLoader: request(path), poll status(path) each frame, take(path) once it is not IN_PROGRESS. A request
## nobody will take any more (a turned-away destination, a freed owner) is joined and dropped with drop(path).


## True when loads may run on worker threads (any renderer but the headless dummy). Constant for the process.
static func threaded() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_driver_name() != "dummy"


## Starts loading `path`. Under the dummy renderer nothing starts: take() loads it on the main thread.
static func request(path: String, type_hint: String = "", use_sub_threads: bool = false) -> Error:
	if not threaded():
		return OK if ResourceLoader.exists(path, type_hint) else ERR_FILE_NOT_FOUND
	return ResourceLoader.load_threaded_request(path, type_hint, use_sub_threads)


## The load's status (ResourceLoader.ThreadLoadStatus). Under the dummy renderer always THREAD_LOAD_LOADED: take() does the work.
static func status(path: String) -> ResourceLoader.ThreadLoadStatus:
	if not threaded():
		return ResourceLoader.THREAD_LOAD_LOADED
	return ResourceLoader.load_threaded_get_status(path)


## The loaded resource (null on failure). Blocks until a threaded load is done; under the dummy renderer a plain main-thread load.
static func take(path: String) -> Resource:
	if not threaded():
		return ResourceLoader.load(path)
	return ResourceLoader.load_threaded_get(path)


## Joins a request whose result nobody wants, so no loader task or result outlives its owner. Free under the dummy renderer.
static func drop(path: String) -> void:
	if threaded():
		ResourceLoader.load_threaded_get(path)
