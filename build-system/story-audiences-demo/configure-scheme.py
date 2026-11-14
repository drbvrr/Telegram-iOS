from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[2]
folder=root/'Telegram/StoryAudiencesNative.xcodeproj/xcshareddata/xcschemes'
tree=ET.parse(folder/'Telegram.xcscheme')
launch=tree.getroot().find('LaunchAction')
assert launch is not None
old=launch.find('CommandLineArguments')
if old is not None:launch.remove(old)
args=ET.SubElement(launch,'CommandLineArguments')
for value in ['--story-audiences-demo','--story-audiences-assets',str(root/'build-system/story-audiences-demo/Assets')]:
 ET.SubElement(args,'CommandLineArgument',argument=value,isEnabled='YES')
ET.indent(tree,space='   ')
tree.write(folder/'StoryAudiencesDemo.xcscheme',encoding='UTF-8',xml_declaration=True)
print('Created native StoryAudiencesDemo scheme')
