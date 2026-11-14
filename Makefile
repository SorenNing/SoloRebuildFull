TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME ?= roothide
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Solo SoloEnhancements

Solo_FILES = Tweak/SoloCore.m Tweak/SOLHome.m Tweak/SOLPreferences.m Tweak/SOLHookRuntime.m Tweak/SoloRecoveredClasses.m
Solo_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
Solo_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore CoreText SystemConfiguration CoreTelephony EventKit
Solo_PRIVATE_FRAMEWORKS = SpringBoardServices FrontBoardServices MediaRemote
Solo_LDFLAGS = -Wl,-undefined,dynamic_lookup
Solo_PLIST = Solo.plist

SoloEnhancements_FILES = Tweak/SoloEnhancements.m Tweak/SOLActions.m Tweak/SOLActionsCatalog.m Tweak/SOLActionsRail.m Tweak/SOLPreferences.m Tweak/SOLHookRuntime.m Tweak/EnhancementsRecoveredClasses.m
SoloEnhancements_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -DSOLPreferences=SOLEnhancementPreferences -DSOLPreferenceDomain=SOLEnhancementPreferenceDomain -DSOLReloadNotification=SOLEnhancementReloadNotification -DSOLPreferencesDidReloadNotification=SOLEnhancementPreferencesDidReloadNotification
SoloEnhancements_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore CoreData ImageIO PhotosUI UniformTypeIdentifiers MediaPlayer
SoloEnhancements_PRIVATE_FRAMEWORKS = Preferences ControlCenterUIKit FrontBoardServices SpringBoardServices
SoloEnhancements_LDFLAGS = -Wl,-undefined,dynamic_lookup
SoloEnhancements_PLIST = SoloEnhancements.plist

BUNDLE_NAME = SoloPrefs
SoloPrefs_FILES = Prefs/SoloPrefs.m
SoloPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SoloPrefs_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore PhotosUI
SoloPrefs_PRIVATE_FRAMEWORKS = Preferences
SoloPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
SoloPrefs_INSTALL_PATH = /Library/PreferenceBundles
SoloPrefs_RESOURCE_DIRS = Resources/SoloPrefs.bundle

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "sbreload"
