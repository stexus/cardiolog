#!/usr/bin/env python3
"""Regenerate the ordinary checked-in Xcode project without external generator dependencies."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, isa, **fields):
    identity=uid(key); objects[identity]={'isa':isa,**fields}; return identity
class Ref(str): pass
def ref(key): return Ref(uid(key))
def encode(value, depth=0):
    if isinstance(value,Ref): return value
    if isinstance(value,str): return json.dumps(value)
    if isinstance(value,list): return '('+', '.join(encode(v, depth+1) for v in value)+')'
    if isinstance(value,dict):
        indent = '\t' * depth
        return '{\n' + ''.join(f'{indent}\t{k} = {encode(v, depth+1)};\n' for k,v in value.items()) + indent + '}'
    return str(value)
sources=sorted((root/'App').glob('*.swift'))
source_refs=[]; source_builds=[]
for path in sources:
    key=str(path.relative_to(root)); source_refs.append(ref(key))
    add(key,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=path.name,sourceTree='<group>')
    add(key+'-build','PBXBuildFile',fileRef=ref(key)); source_builds.append(ref(key+'-build'))
resources=[]
for path,kind in [('Assets.xcassets','folder.assetcatalog'),('PrivacyInfo.xcprivacy','text.xml')]:
    add(path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>'); source_refs.append(ref(path))
    add(path+'-build','PBXBuildFile',fileRef=ref(path)); resources.append(ref(path+'-build'))
for path,kind in [('Info.plist','text.plist.xml'),('CardioLog.entitlements','text.plist.entitlements')]:
    add(path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>'); source_refs.append(ref(path))
add('app-group','PBXGroup',children=source_refs,path='App',sourceTree='<group>')
configs=[]
for name in ['Base','Debug','Dev','Release']:
    add('config-'+name,'PBXFileReference',lastKnownFileType='text.xcconfig',path=name+'.xcconfig',sourceTree='<group>'); configs.append(ref('config-'+name))
add('config-group','PBXGroup',children=configs,path='Config',sourceTree='<group>')
add('product','PBXFileReference',explicitFileType='wrapper.application',path='CardioLog.app',sourceTree='BUILT_PRODUCTS_DIR')
add('test-product','PBXFileReference',explicitFileType='wrapper.cfbundle',path='CardioLogUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
add('products','PBXGroup',children=[ref('product'),ref('test-product')],name='Products',sourceTree='<group>')
add('test-source','PBXFileReference',lastKnownFileType='sourcecode.swift',path='AppUITests/CardioLogUITests.swift',sourceTree='<group>')
add('test-build','PBXBuildFile',fileRef=ref('test-source'))
add('main-group','PBXGroup',children=[ref('app-group'),ref('test-source'),ref('config-group'),ref('products')],sourceTree='<group>')
add('sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=source_builds,runOnlyForDeploymentPostprocessing=0)
add('resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resources,runOnlyForDeploymentPostprocessing=0)
add('package','XCLocalSwiftPackageReference',relativePath='.')
products=[]; frameworks=[]
for name in ['CardioLogCore','CardioLogPersistence']:
    add(name,'XCSwiftPackageProductDependency',productName=name); products.append(ref(name))
    add(name+'-link','PBXBuildFile',productRef=ref(name)); frameworks.append(ref(name+'-link'))
add('frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=frameworks,runOnlyForDeploymentPostprocessing=0)
for scope in ['project','app','test']:
    config_refs=[]
    for name in ['Debug','Dev','Release']:
        key=scope+'-'+name; config_refs.append(ref(key)); settings={}; fields={}
        if scope=='app': fields['baseConfigurationReference']=ref('config-'+name)
        elif scope=='project': settings={'IPHONEOS_DEPLOYMENT_TARGET':'26.0','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES'}
        else: settings={'PRODUCT_BUNDLE_IDENTIFIER':'app.cardiolog.uitests','PRODUCT_NAME':'CardioLogUITests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'CardioLog','TARGETED_DEVICE_FAMILY':'1','SDKROOT':'iphoneos','CODE_SIGN_STYLE':'Automatic','SWIFT_VERSION':'6.0','SWIFT_OPTIMIZATION_LEVEL':'-Onone','ENABLE_TESTABILITY':'YES'}
        add(key,'XCBuildConfiguration',buildSettings=settings,name=name,**fields)
    add(scope+'-configs','XCConfigurationList',buildConfigurations=config_refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
add('app','PBXNativeTarget',buildConfigurationList=ref('app-configs'),buildPhases=[ref('sources'),ref('frameworks'),ref('resources')],buildRules=[],dependencies=[],name='CardioLog',packageProductDependencies=products,productName='CardioLog',productReference=ref('product'),productType='com.apple.product-type.application')
add('test-sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[ref('test-build')],runOnlyForDeploymentPostprocessing=0)
add('proxy','PBXContainerItemProxy',containerPortal=ref('project'),proxyType=1,remoteGlobalIDString=ref('app'),remoteInfo='CardioLog')
add('dependency','PBXTargetDependency',target=ref('app'),targetProxy=ref('proxy'))
add('tests','PBXNativeTarget',buildConfigurationList=ref('test-configs'),buildPhases=[ref('test-sources')],buildRules=[],dependencies=[ref('dependency')],name='CardioLogUITests',productName='CardioLogUITests',productReference=ref('test-product'),productType='com.apple.product-type.bundle.ui-testing')
add('project','PBXProject',attributes={'LastUpgradeCheck':'2630','TargetAttributes':{uid('app'):{'CreatedOnToolsVersion':'26.3'},uid('tests'):{'CreatedOnToolsVersion':'26.3','TestTargetID':ref('app')}}},buildConfigurationList=ref('project-configs'),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=ref('main-group'),packageReferences=[ref('package')],productRefGroup=ref('products'),projectDirPath='',projectRoot='',targets=[ref('app'),ref('tests')])
project=root/'CardioLog.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':60,'objects':objects,'rootObject':ref('project')})+'\n')
shared=project/'xcshareddata/xcschemes'; shared.mkdir(parents=True,exist_ok=True)
for scheme,config in [('CardioLogDev','Dev'),('CardioLog','Release')]:
    app=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("app")}" BuildableName="CardioLog.app" BlueprintName="CardioLog" ReferencedContainer="container:CardioLog.xcodeproj"/>'
    test=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("tests")}" BuildableName="CardioLogUITests.xctest" BlueprintName="CardioLogUITests" ReferencedContainer="container:CardioLog.xcodeproj"/>'
    (shared/(scheme+'.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="{config}" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="{config}" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated CardioLog.xcodeproj and shared schemes')
