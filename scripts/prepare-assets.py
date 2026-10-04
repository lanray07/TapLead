"""Build an original geometric app icon and copy the widget string catalogue.
Requires Pillow. Generates no imitation iOS screenshots or user portraits.
"""
import json, pathlib, shutil
from PIL import Image, ImageDraw
root=pathlib.Path(__file__).resolve().parents[1]
assets=root/'iOS/TapLead/Resources/Assets.xcassets'
icon=assets/'AppIcon.appiconset'
icon.mkdir(parents=True,exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
image=Image.new('RGB',(1024,1024),'#6654D9')
draw=ImageDraw.Draw(image)
# Two open connection cards, linked by a purposeful forward arrow.
draw.rounded_rectangle((211,218,690,706),radius=96,outline='#CFC6FF',width=44)
draw.rounded_rectangle((341,346,820,834),radius=96,fill='#6654D9',outline='white',width=44)
draw.line((443,688,691,440),fill='white',width=47)
draw.line((535,439,696,439,696,600),fill='white',width=47,joint='curve')
image.save(icon/'AppIcon.png')
(icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
catalog=root/'iOS/TapLead/Resources/Localizable.xcstrings'
widget=root/'iOS/Widget/Resources'
widget.mkdir(parents=True,exist_ok=True)
if catalog.exists():shutil.copy2(catalog,widget/'Localizable.xcstrings')
print('App icon and widget resources prepared.')
