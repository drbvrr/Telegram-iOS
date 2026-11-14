from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(k,v): objects[uid(k)]=v;return uid(k)
def arr(v): return '('+','.join(v)+',)'
source=add('source','{isa=PBXFileReference; lastKnownFileType=sourcecode.swift; path=Tests/NativeFlowTests.swift; sourceTree=SOURCE_ROOT;}')
build=add('build','{isa=PBXBuildFile; fileRef='+source+';}')
phase=add('phase','{isa=PBXSourcesBuildPhase; buildActionMask=2147483647; files='+arr([build])+'; runOnlyForDeploymentPostprocessing=0;}')
product=add('product','{isa=PBXFileReference; explicitFileType=wrapper.cfbundle; path=NativeFlowTests.xctest; sourceTree=BUILT_PRODUCTS_DIR;}')
group=add('group','{isa=PBXGroup; children='+arr([source,product])+'; sourceTree="<group>";}')
configs=[]
for name in ['Debug','Release']:
 configs.append(add(name,'{isa=XCBuildConfiguration; name='+name+'; buildSettings={PRODUCT_BUNDLE_IDENTIFIER=design.storyaudiences.nativechecks; PRODUCT_NAME="$(TARGET_NAME)"; SWIFT_VERSION=5.0; IPHONEOS_DEPLOYMENT_TARGET=17.0; TARGETED_DEVICE_FAMILY=1; GENERATE_INFOPLIST_FILE=YES; SDKROOT=iphonesimulator; CODE_SIGNING_ALLOWED=NO;};}'))
cl=add('cl','{isa=XCConfigurationList; buildConfigurations='+arr(configs)+'; defaultConfigurationName=Debug;}')
target=add('target','{isa=PBXNativeTarget; buildConfigurationList='+cl+'; buildPhases='+arr([phase])+'; dependencies=(); name=NativeFlowTests; productName=NativeFlowTests; productReference='+product+'; productType="com.apple.product-type.bundle.ui-testing";}')
project=add('project','{isa=PBXProject; attributes={LastUpgradeCheck=2700;}; buildConfigurationList='+cl+'; compatibilityVersion="Xcode 14.0"; developmentRegion=en; hasScannedForEncodings=0; knownRegions=(en,Base); mainGroup='+group+'; projectDirPath=""; projectRoot=""; targets='+arr([target])+';}')
folder=root/'NativeFlowTests.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1; classes={}; objectVersion=56; objects={'+''.join(k+'='+v+';\n' for k,v in objects.items())+'}; rootObject='+project+';}')
ref='<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'+target+'" BuildableName="NativeFlowTests.xctest" BlueprintName="NativeFlowTests" ReferencedContainer="container:NativeFlowTests.xcodeproj"/>'
schemes=folder/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'NativeFlowTests.xcscheme').write_text('<?xml version="1.0"?><Scheme version="1.3"><BuildAction parallelizeBuildables="NO" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">'+ref+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><Testables><TestableReference skipped="NO">'+ref+'</TestableReference></Testables></TestAction></Scheme>')
print(folder)
