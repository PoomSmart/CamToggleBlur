ARCHS = armv7 armv7s arm64
SDKVERSION = 7.0

include theos/makefiles/common.mk
TWEAK_NAME = CamToggleBlur
CamToggleBlur_FILES = Tweak.xm
CamToggleBlur_FRAMEWORKS = UIKit
CamToggleBlur_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
