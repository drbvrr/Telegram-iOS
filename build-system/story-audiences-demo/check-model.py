"""Check the production store's persistence/mutation methods with Foundation.
Signal notification delivery and UIKit are tested separately in the native app.
The tiny notification adapter below only allows running those same methods on macOS.
"""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[2]
source=(root/'submodules/TelegramCore/Sources/Account/StoryAudienceStore.swift').read_text().replace('import SwiftSignalKit','')
adapter='''
import Foundation
public enum NoError: Error {}
public final class Signal<T,E: Error> {}
public final class ValuePromise<T> {
 public init(_ value:T,ignoreRepeated:Bool) {}
 public func get()->Signal<T,NoError> { Signal() }
 public func set(_ value:T) {}
}
public final class Account { public let basePath:String; public init(basePath:String) { self.basePath=basePath } }
'''
checks='''
let path = CommandLine.arguments[1]
let store = StoryAudienceStore(path:path)
assert(store.save(id:nil,name:"  ",icon:"Person",members:[]) == nil)
assert(store.value.audiences.isEmpty)
let a = store.save(id:nil,name:"Team",icon:"Person",members:[])!
let b = store.save(id:nil,name:"Team",icon:"Code",members:[2])!
assert(a.id != b.id && store.value.audiences.count == 2)
assert(a.members.isEmpty && a.colorIndex == 0 && b.colorIndex == 1)
store.select(a.id)
_ = store.save(id:b.id,name:"Other team",icon:"Code",members:[2])
assert(store.value.selectedId == a.id)
store.publish(id:1,base:"nobody",members:[])
let edited = store.save(id:a.id,name:"Team",icon:"Code",members:[9,7,9])!
assert(edited.members == [7,9] && edited.colorIndex == a.colorIndex)
assert(store.value.stories[0].members == [7,9])
store.delete(a.id)
assert(store.value.selectedId == nil)
assert(store.value.stories[0].audienceId == nil && store.value.stories[0].base == "everyone" && store.value.stories[0].members.isEmpty)
assert(store.audience(b.id)!.colorIndex == 1)
let c = store.save(id:nil,name:"Next",icon:"Person",members:[])!
assert(c.colorIndex == 2)
store.select(b.id)
store.publish(id:2,base:"nobody",members:[2])
store.changeStory(id:2,audienceId:c.id,base:"nobody",members:[])
assert(store.value.stories.first(where: {$0.id == 2})!.members.isEmpty)
assert(store.value.stories.first(where: {$0.id == 2})!.audienceId == c.id)
_ = store.save(id:b.id,name:"Old list",icon:"Code",members:[99])
assert(store.value.stories.first(where: {$0.id == 2})!.members.isEmpty)
store.delete(b.id)
assert(store.value.stories.first(where: {$0.id == 2})!.audienceId == c.id)
store.changeStory(id:2,audienceId:nil,base:"contacts",members:[7])
assert(store.value.stories.first(where: {$0.id == 2})!.base == "contacts")
assert(store.value.stories.first(where: {$0.id == 2})!.members == [7])
assert(store.value.stories.first(where: {$0.id == 2})!.audienceId == nil)
let restored = StoryAudienceStore(path:path)
assert(restored.value == store.value)
print("Model checks passed: validation, duplicate names, empty members, retroactive access, deletion fallback, stable colors, replacement privacy without old members and persistence.")
'''
with tempfile.TemporaryDirectory(prefix='story-audience-model-') as tmp:
 p=Path(tmp);(p/'main.swift').write_text(adapter+source+checks)
 subprocess.run(['swift',str(p/'main.swift'),str(p/'state.json')],check=True)
