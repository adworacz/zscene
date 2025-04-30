# zscene

## ReadScene
```python
core.zscene.ReadScenes(path=string)
```

Reads scene data from a given file. Adds the pertinent `_SceneChangePrev` and `_SceneChangeNext` properties
to each frame.

Currently only supports the JSON file emitted from https://github.com/rust-av/av-scenechange, although there's 
no reason other scene file formats can't be added. Feel free to open an issue to request one.

## Scene File Generation
Scene data can be generated using something like the following:

```sh
vspipe -c y4m source.vpy - | av-scenechange -o scenes.json -
```

Note that `av-scenechange` can be built with Vapoursynth and FFMPEG support built in, 
so there are a variety of ways that it can be fed with video data. Choose what works best
for you.
