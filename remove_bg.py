import sys
from PIL import Image

def remove_white_bg(input_path, output_path):
    try:
        img = Image.open(input_path).convert("RGBA")
        datas = img.getdata()
        
        newData = []
        for item in datas:
            # Change all white (also shades of whites)
            # to transparent
            if item[0] > 240 and item[1] > 240 and item[2] > 240:
                newData.append((255, 255, 255, 0))
            else:
                newData.append(item)
                
        img.putdata(newData)
        img.save(output_path, "PNG")
        print(f"Saved {output_path}")
    except Exception as e:
        print(f"Error: {e}")

remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/onboarding_welcome_1782859321311.jpg", "onboarding_welcome.png")
remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/onboarding_location_1782859336444.jpg", "onboarding_location.png")
remove_white_bg("/Users/mosaab/.gemini/antigravity/brain/c3f30668-ef8e-49be-ab08-9ecd4d454791/onboarding_time_1782859353220.jpg", "onboarding_time.png")
