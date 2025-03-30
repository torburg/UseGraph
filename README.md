UseGraph
=====================

## How To Use

### Install

```sh
mint install rofle100lvl/UseGraph
```

### Usage
If you want to use Dynamic analyse, you should call
```sh
mise run UseGraph use_graph usage_graph_dynamic
--schemes <scheme to build>
--project-path <path to your workspace/xbproj/Package.swift file>
--index-store <path to your index store data folder
 ~/Library/Developer/Xcode/DerivedData/<your-project>/Index.noindex/DataStore/>
```

If you want to use Monolite destroyer, you should call
```sh
mise run UseGraph use_graph usage_graph_dynamic_analyze
--schemes <scheme to build>
--project-path <path to your workspace/xbproj/Package.swift file>
--folder-paths <Paths to folder with sources - "path1,path2,path3">
--index-store <path to your index store data folder
~/Library/Developer/Xcode/DerivedData/<your-project>/Index.noindex/DataStore/>
```
