import sys
from PIL import Image

def remove_white_bg(input_path, output_path, resize=None):
    try:
        img = Image.open(input_path).convert("RGBA")
        datas = img.getdata()
        
        newData = []
        for item in datas:
            if item[0] > 240 and item[1] > 240 and item[2] > 240:
                newData.append((255, 255, 255, 0))
            else:
                newData.append(item)
                
        img.putdata(newData)
        
        if resize:
            img = img.resize(resize, Image.Resampling.LANCZOS)
            
        img.save(output_path, "PNG")
        print(f"Saved {output_path}")
    except Exception as e:
        print(f"Error: {e}")

# Process Onboarding Images (Keep original size)
remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/pebble_welcome_1782859982461.jpg", "onboarding_welcome.png")
remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/pebble_location_1782859998456.jpg", "onboarding_location.png")
remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/pebble_time_1782860012984.jpg", "onboarding_time.png")

# Process App Icon (Resize to 1024x1024 and keep background opaque because iOS app icons don't support transparency)
try:
    img = Image.open("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/pebble_app_icon_1782860028626.jpg").convert("RGB")
    img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    img.save("app_icon_1024.png", "PNG")
    print("Saved app_icon_1024.png")
except Exception as e:
    print(f"Error saving app icon: {e}")

