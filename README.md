# zscene

## ReadScene
```python
core.zscene.ReadScenes(path=string, format=int)
```

Reads scene data from a given file. Adds the pertinent `_SceneChangePrev` and `_SceneChangeNext` properties
to each frame.

### Supported Formats

| Format | Format Code | Description |
| ---    | ---         | ---         |
| JSON   | 0           | JSON files produced by [av-scenechange](https://github.com/rust-av/av-scenechange). The JSON must have the `scene_changes` and `frame_count` fields. |
| QP File| 1           | Text files with frame numbers listed on new lines. Often used with x264 or x265 and their [`--qpfile`](https://x265.readthedocs.io/en/master/cli.html#cmdoption-qpfile) parameters. Scenes will be marked as scene changes if they have a `K` or `I` (but not `i`) frame type, or if the frame type is omitted completely.|

Feel free to open an issue to request scene file formats.

Examples:
- [Av Scene Change JSON](src/test_scenes.json)
- [QP File](src/test_scenes.qpfile)
- [QP File - with no frame types](src/test_scenes_no_frametype.qpfile)

## Scene File Generation
Scene data can be generated using something like the following:

```sh
vspipe -c y4m source.vpy - | av-scenechange -o scenes.json -
```

Note that `av-scenechange` can be built with Vapoursynth and FFMPEG support built in, 
so there are a variety of ways that it can be fed with video data. Choose what works best
for you.

Ref: https://github.com/rust-av/av-scenechange
