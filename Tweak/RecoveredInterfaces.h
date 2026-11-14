/*
 * SoloRebuild recovered interfaces.
 * Generated from Objective-C metadata in Solo 1.0.1-12.
 * Method bodies, private ABI details and original source names are not recovered here.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#if __has_include(<Preferences/Preferences.h>)
#import <Preferences/Preferences.h>
#else
@interface PSListController : UIViewController @end
@interface PSViewController : UIViewController @end
#endif

@interface UnduoWeatherLocationDelegate : NSObject
// Recovered selectors:
//   locationManager:didUpdateLocations:
//   locationManager:didFailWithError:
//   cityDidFinishWeatherUpdate:
@end

@interface UnduoPlusTapHandler : NSObject
// Recovered selectors:
//   handleTap:
@end

@interface UnduoSearchButtonTapHandler : NSObject
// Recovered selectors:
//   handleTap:
@end

@interface UnduoBackdropBlurView : UIView
// Recovered selectors:
//   layerClass
@end

@interface UnduoGlassBackingView : UIVisualEffectView
{
    UIView * _glassView;
}
@property(nonatomic, strong) UIView * glassView;
// Recovered selectors:
//   layoutSubviews
//   glassView
//   setGlassView:
@end

@interface UnduoWidgetPlatterTapHandler : NSObject
// Recovered selectors:
//   gestureRecognizerShouldBegin:
//   handleTap:
@end

@interface UnduoStatusRingTapHandler : NSObject
// Recovered selectors:
//   handleRingTap:
@end

@interface UnduoRadialShadowView : UIView
// Recovered selectors:
//   layerClass
@end

@interface UnduoWelcomeGradientView : UIView
@property(nonatomic, strong) id gradient;
// Recovered selectors:
//   gradient
//   layerClass
@end

@interface UnduoWelcomeViewController : UIViewController
// Recovered selectors:
//   supportedInterfaceOrientations
//   shouldAutorotate
@end

@interface UnduoWelcomeSheet : NSObject
{
    UIWindow * _window;
    UIView * _dim;
    CALayer * _backdrop;
    UIView * _card;
    UIView * _content;
    UIImageView * _icon;
    UIView * _textBox;
    UILabel * _titleLabel;
    UILabel * _bodyLabel;
    UIView * _mockup;
    UnduoWelcomeGradientView * _mockupFade;
    UIView * _phone;
    UIView * _screen;
    UIView * _carouselStrip;
    UIView * _carouselWidget;
    UIView * _widgetSlot;
    UIView * _dragWidget;
    UIView * _removeBadge;
    UIView * _picker;
    UIView * _pickerPreview;
    UIView * _pickerButton;
    UIView * _settings;
    UIView * _soloRow;
    UIPageControl * _dots;
    UIButton * _button;
    NSInteger _page;
    NSUInteger _token;
}
@property(nonatomic, strong) UIWindow * window;
@property(nonatomic, strong) UIView * dim;
@property(nonatomic, strong) CALayer * backdrop;
@property(nonatomic, strong) UIView * card;
@property(nonatomic, strong) UIView * content;
@property(nonatomic, strong) UIImageView * icon;
@property(nonatomic, strong) UIView * textBox;
@property(nonatomic, strong) UILabel * titleLabel;
@property(nonatomic, strong) UILabel * bodyLabel;
@property(nonatomic, strong) UIView * mockup;
@property(nonatomic, strong) UnduoWelcomeGradientView * mockupFade;
@property(nonatomic, strong) UIView * phone;
@property(nonatomic, strong) UIView * screen;
@property(nonatomic, strong) UIView * carouselStrip;
@property(nonatomic, strong) UIView * carouselWidget;
@property(nonatomic, strong) UIView * widgetSlot;
@property(nonatomic, strong) UIView * dragWidget;
@property(nonatomic, strong) UIView * removeBadge;
@property(nonatomic, strong) UIView * picker;
@property(nonatomic, strong) UIView * pickerPreview;
@property(nonatomic, strong) UIView * pickerButton;
@property(nonatomic, strong) UIView * settings;
@property(nonatomic, strong) UIView * soloRow;
@property(nonatomic, strong) UIPageControl * dots;
@property(nonatomic, strong) UIButton * button;
@property(nonatomic, assign) NSInteger page;
@property(nonatomic, assign) NSUInteger token;
// Recovered selectors:
//   textTopForStep:
//   footerTop
//   textFrameForStep:
//   areaForStep:
//   placePhoneForStep:area:
//   settingsScale
//   layOutStep:
//   setMockupFaded:animated:
//   setText:animated:
//   setIconShown:animated:
//   resetWidgetPieces:
//   goToStep:animated:
//   after:token:do:
//   flipCarouselFrom:token:
//   liftDragWidget:
//   landDragWidgetWithToken:then:
//   playWidgetStepWithToken:
//   tapSoloRow:token:
//   setBackdropBlur:duration:
//   next
//   previous
//   dotsChanged:
//   window
//   setWindow:
//   dim
//   setDim:
//   backdrop
//   setBackdrop:
//   card
//   setCard:
//   content
//   setContent:
//   icon
//   setIcon:
//   textBox
//   setTextBox:
//   titleLabel
//   setTitleLabel:
//   bodyLabel
//   setBodyLabel:
//   mockup
//   setMockup:
//   mockupFade
//   setMockupFade:
//   phone
//   setPhone:
//   screen
//   setScreen:
//   carouselStrip
//   setCarouselStrip:
//   carouselWidget
//   setCarouselWidget:
//   widgetSlot
//   setWidgetSlot:
//   dragWidget
//   setDragWidget:
//   removeBadge
//   setRemoveBadge:
//   picker
//   setPicker:
//   pickerPreview
//   setPickerPreview:
//   pickerButton
//   setPickerButton:
//   settings
//   setSettings:
//   soloRow
//   setSoloRow:
//   dots
//   setDots:
//   button
//   setButton:
//   page
//   setPage:
//   token
//   setToken:
@end

@interface UnduoWidgetTapHandler : NSObject
// Recovered selectors:
//   handleWidgetTap:
@end

@interface UnduoWidgetRemoveTapHandler : NSObject
// Recovered selectors:
//   handleRemoveTap:
@end

@interface UnduoCarouselDropTarget : NSObject
// Recovered selectors:
//   dropInteraction:canHandleSession:
//   dropInteraction:sessionDidEnter:
//   dropInteraction:sessionDidUpdate:
//   dropInteraction:sessionDidExit:
@end

@interface UnduoClockMirroredLabel : UILabel
{
    NSString * _unduoRawText;
    BOOL _unduoUppercase;
    CGFloat _unduoKern;
    CGFloat _unduoSuffixScale;
}
@property(nonatomic, assign) BOOL unduoUppercase;
@property(nonatomic, assign) CGFloat unduoKern;
@property(nonatomic, assign) CGFloat unduoSuffixScale;
@property(nonatomic, strong) NSString * unduoRawText;
// Recovered selectors:
//   unduoRawText
//   setText:
//   unduoRender
//   setFont:
//   setTextColor:
//   unduoUppercase
//   setUnduoUppercase:
//   unduoKern
//   setUnduoKern:
//   unduoSuffixScale
//   setUnduoSuffixScale:
@end

@interface UnduoClockMirroredImageView : UIImageView
// Recovered selectors:
//   setImage:
@end

@interface UnduoMediaRemoteObserver : NSObject
// Recovered selectors:
//   unduoNowPlayingInfoChanged:
//   unduoNowPlayingApplicationIsPlayingChanged:
@end

@interface UnduoMediaProgressTickHandler : NSObject
// Recovered selectors:
//   tick
@end

@interface UnduoGradientView : UIView
// Recovered selectors:
//   layerClass
@end

@interface UnduoMediaPlayerContainerView : UIView
// Recovered selectors:
//   traitCollectionDidChange:
@end

@interface UnduoMediaTransportHandler : NSObject
// Recovered selectors:
//   handleArtTap:
//   handlePlayPause:
//   handleBack:
//   handleSkip:
//   handleTouchDown:
//   handleTouchUp:
@end

@interface UnduoMediaScrubHandler : NSObject
// Recovered selectors:
//   gestureRecognizerShouldBegin:
//   handlePan:
@end

@interface UnduoPassthroughView : UIView
// Recovered selectors:
//   hitTest:withEvent:
@end

@interface UnduoMediaPaneSwipeHandler : NSObject
// Recovered selectors:
//   gestureRecognizerShouldBegin:
//   handlePan:
//   handleLyricsTap:
@end

@interface UnduoClockTapHandler : NSObject
// Recovered selectors:
//   handleClockTap:
//   handleDateTap:
//   handleWeatherTap:
//   handleFaceTap:
//   gestureRecognizer:shouldReceiveTouch:
@end

@interface UnduoAppearanceObserverView : UIView
// Recovered selectors:
//   traitCollectionDidChange:
//   didMoveToWindow
@end

@interface UnduoWiggleExitCorrectionTickHandler : NSObject
// Recovered selectors:
//   tick
@end

@interface UnduoRemoveButtonMaskTickHandler : NSObject
// Recovered selectors:
//   tick
@end

@interface UnduoCalendarTapHandler : NSObject
// Recovered selectors:
//   handleRowTap:
//   handleBadgeTap:
//   handleMonthTap:
@end

@interface UnduoShortcutTapHandler : NSObject
// Recovered selectors:
//   handleTap:
@end

@interface UnduoPlatterFrameDriver : NSObject
// Recovered selectors:
//   tick:
//   applyFrame:
@end

@interface UnduoPlatterPagePanHandler : NSObject
// Recovered selectors:
//   gestureRecognizerShouldBegin:
//   handlePan:
@end

@interface SXShortcutBackdropView : UIView
{
    NSString * _styleIdentifier;
    UIVisualEffectView * _material;
    CAGradientLayer * _wash;
    CAGradientLayer * _sheen;
}
@property(nonatomic, strong) UIVisualEffectView * material;
@property(nonatomic, strong) CAGradientLayer * wash;
@property(nonatomic, strong) CAGradientLayer * sheen;
@property(nonatomic, strong) NSString * styleIdentifier;
// Recovered selectors:
//   initWithFrame:
//   dealloc
//   setStyleIdentifier:
//   accessibilityChanged:
//   traitCollectionDidChange:
//   updateAppearance
//   layoutSubviews
//   styleIdentifier
//   material
//   setMaterial:
//   wash
//   setWash:
//   sheen
//   setSheen:
@end

@interface SXDockGestureDelegate : NSObject
{
    id _original;
}
@property(nonatomic, strong) id original;
// Recovered selectors:
//   respondsToSelector:
//   forwardingTargetForSelector:
//   gestureRecognizer:shouldReceiveTouch:
//   gestureRecognizerShouldBegin:
//   gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:
//   gestureRecognizer:shouldRequireFailureOfGestureRecognizer:
//   gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:
//   gestureRecognizer:shouldReceivePress:
//   gestureRecognizer:shouldReceiveEvent:
//   original
//   setOriginal:
@end

@interface SXGridLayout : UICollectionViewLayout
{
    BOOL _vertical;
    CGFloat _rowHeight;
}
@property(nonatomic, assign) BOOL vertical;
@property(nonatomic, assign) CGFloat rowHeight;
// Recovered selectors:
//   collectionViewContentSize
//   layoutAttributesForItemAtIndexPath:
//   layoutAttributesForElementsInRect:
//   shouldInvalidateLayoutForBoundsChange:
//   vertical
//   setVertical:
//   rowHeight
//   setRowHeight:
@end

@interface SXAxisCollection : UICollectionView
{
    BOOL _vertical;
}
@property(nonatomic, assign) BOOL vertical;
// Recovered selectors:
//   gestureRecognizerShouldBegin:
//   vertical
//   setVertical:
@end

@interface SXActionCell : UICollectionViewCell
{
    UIImageView * _icon;
    UILabel * _nameLabel;
    UIVisualEffectView * _backing;
    UIView * _stateBackground;
    NSString * _representedID;
    NSDictionary * _action;
    NSNumber * _displayedState;
    CGFloat _iconSize;
}
@property(nonatomic, strong) UIImageView * icon;
@property(nonatomic, strong) UILabel * nameLabel;
@property(nonatomic, strong) UIVisualEffectView * backing;
@property(nonatomic, strong) UIView * stateBackground;
@property(nonatomic, strong) NSString * representedID;
@property(nonatomic, strong) NSDictionary * action;
@property(nonatomic, strong) NSNumber * displayedState;
@property(nonatomic, assign) CGFloat iconSize;
// Recovered selectors:
//   initWithFrame:
//   setAction:
//   layoutSubviews
//   traitCollectionDidChange:
//   prepareForReuse
//   applyState:
//   setHighlighted:
//   icon
//   setIcon:
//   nameLabel
//   setNameLabel:
//   backing
//   setBacking:
//   stateBackground
//   setStateBackground:
//   representedID
//   setRepresentedID:
//   action
//   displayedState
//   setDisplayedState:
//   iconSize
//   setIconSize:
@end

@interface SXActionView : UIView
{
    BOOL _vertical;
    BOOL _glassStyle;
    SXAxisCollection * _collection;
    SXGridLayout * _grid;
    UIPageControl * _pages;
    NSArray * _actions;
    CGFloat _iconSize;
    UILabel * _emptyLabel;
    NSTimer * _stateTimer;
}
@property(nonatomic, assign) BOOL vertical;
@property(nonatomic, strong) SXAxisCollection * collection;
@property(nonatomic, strong) SXGridLayout * grid;
@property(nonatomic, strong) UIPageControl * pages;
@property(nonatomic, strong) NSArray * actions;
@property(nonatomic, assign) CGFloat iconSize;
@property(nonatomic, strong) UILabel * emptyLabel;
@property(nonatomic, strong) NSTimer * stateTimer;
@property(nonatomic, assign) BOOL glassStyle;
// Recovered selectors:
//   applyBackgroundStyle:
//   initVertical:
//   didMoveToWindow
//   dealloc
//   actionStateChanged:
//   refreshToolStates
//   reloadActions:
//   layoutSubviews
//   collectionView:numberOfItemsInSection:
//   collectionView:cellForItemAtIndexPath:
//   collectionView:didSelectItemAtIndexPath:
//   scrollViewDidScroll:
//   changePage
//   vertical
//   setVertical:
//   collection
//   setCollection:
//   grid
//   setGrid:
//   pages
//   setPages:
//   actions
//   setActions:
//   iconSize
//   setIconSize:
//   emptyLabel
//   setEmptyLabel:
//   stateTimer
//   setStateTimer:
//   glassStyle
//   setGlassStyle:
//   collectionView:numberOfItemsInSection:
//   collectionView:cellForItemAtIndexPath:
//   collectionView:numberOfItemsInSection:
//   collectionView:cellForItemAtIndexPath:
@end

@interface SXSystemControlController : UIViewController
{
    NSString * _kind;
    UISlider * _brightness;
}
@property(nonatomic, strong) NSString * kind;
@property(nonatomic, strong) UISlider * brightness;
// Recovered selectors:
//   viewDidLoad
//   brightnessChanged:
//   refreshBrightness:
//   dealloc
//   kind
//   setKind:
//   brightness
//   setBrightness:
@end

@interface SXPicker : UITableViewController
{
    NSArray * _records;
    NSArray * _filtered;
    id _choose;
    id _selected;
    UISearchController * _search;
}
@property(nonatomic, strong) NSArray * records;
@property(nonatomic, strong) NSArray * filtered;
@property(nonatomic, strong) id choose;
@property(nonatomic, strong) id selected;
@property(nonatomic, strong) UISearchController * search;
// Recovered selectors:
//   viewDidLoad
//   done
//   updateSearchResultsForSearchController:
//   tableView:numberOfRowsInSection:
//   tableView:cellForRowAtIndexPath:
//   tableView:didSelectRowAtIndexPath:
//   records
//   setRecords:
//   filtered
//   setFiltered:
//   choose
//   setChoose:
//   selected
//   setSelected:
//   search
//   setSearch:
//   updateSearchResultsForSearchController:
//   updateSearchResultsForSearchController:
@end

@interface SXShortcutStyleController : UITableViewController
{
    NSString * _selectedStyle;
    id _styleChanged;
    UIView * _previewContainer;
    UIView * _previewSurface;
    SXShortcutBackdropView * _previewBackdrop;
    SXActionView * _previewGrid;
}
@property(nonatomic, strong) NSString * selectedStyle;
@property(nonatomic, strong) id styleChanged;
@property(nonatomic, strong) UIView * previewContainer;
@property(nonatomic, strong) UIView * previewSurface;
@property(nonatomic, strong) SXShortcutBackdropView * previewBackdrop;
@property(nonatomic, strong) SXActionView * previewGrid;
// Recovered selectors:
//   init
//   viewDidLoad
//   viewDidLayoutSubviews
//   updatePreview
//   done
//   tableView:numberOfRowsInSection:
//   tableView:cellForRowAtIndexPath:
//   selectStyle:
//   tableView:didSelectRowAtIndexPath:
//   selectedStyle
//   setSelectedStyle:
//   styleChanged
//   setStyleChanged:
//   previewContainer
//   setPreviewContainer:
//   previewSurface
//   setPreviewSurface:
//   previewBackdrop
//   setPreviewBackdrop:
//   previewGrid
//   setPreviewGrid:
@end

@interface SXActionEditor : UITableViewController
{
    NSString * _preferenceKey;
    NSMutableArray * _records;
    UIViewController * _navigationOwner;
}
@property(nonatomic, strong) NSMutableArray * records;
@property(nonatomic, strong) UIViewController * navigationOwner;
@property(nonatomic, strong) NSString * preferenceKey;
// Recovered selectors:
//   init
//   viewDidLoad
//   configureNavigation:
//   toggleEditing
//   sizeKey
//   modeKey
//   list:
//   save
//   numberOfSectionsInTableView:
//   tableView:numberOfRowsInSection:
//   tableView:titleForHeaderInSection:
//   tableView:cellForRowAtIndexPath:
//   sizeChanged:
//   enabledChanged:
//   tableView:canEditRowAtIndexPath:
//   tableView:canMoveRowAtIndexPath:
//   tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:
//   tableView:moveRowAtIndexPath:toIndexPath:
//   tableView:commitEditingStyle:forRowAtIndexPath:
//   showPicker:title:choose:selected:
//   selectMode:completion:
//   applyAppMode:
//   tableView:didSelectRowAtIndexPath:
//   addRecord:
//   pickRecords:title:
//   add
//   addCategory:
//   editURL:
//   preferenceKey
//   setPreferenceKey:
//   records
//   setRecords:
//   navigationOwner
//   setNavigationOwner:
@end

@interface SXClockController : UITableViewController
{
    UIImageView * _preview;
    NSUInteger _importGeneration;
}
@property(nonatomic, strong) UIImageView * preview;
@property(nonatomic, assign) NSUInteger importGeneration;
// Recovered selectors:
//   init
//   setSpecifier:
//   viewDidLoad
//   tableView:numberOfRowsInSection:
//   tableView:heightForRowAtIndexPath:
//   tableView:cellForRowAtIndexPath:
//   opacity:
//   tableView:didSelectRowAtIndexPath:
//   importData:
//   importData:generation:
//   picker:didFinishPicking:
//   documentPicker:didPickDocumentsAtURLs:
//   preview
//   setPreview:
//   importGeneration
//   setImportGeneration:
//   picker:didFinishPicking:
//   picker:didFinishPicking:
@end

@interface SXShortcutPlatterState : NSObject
{
    UIVisualEffect * _originalEffect;
    UIColor * _originalBackground;
    UIColor * _originalContentBackground;
    NSMapTable * _nativeBackgrounds;
    SXShortcutBackdropView * _backdrop;
}
@property(nonatomic, strong) UIVisualEffect * originalEffect;
@property(nonatomic, strong) UIColor * originalBackground;
@property(nonatomic, strong) UIColor * originalContentBackground;
@property(nonatomic, strong) NSMapTable * nativeBackgrounds;
@property(nonatomic, strong) SXShortcutBackdropView * backdrop;
// Recovered selectors:
//   originalEffect
//   setOriginalEffect:
//   originalBackground
//   setOriginalBackground:
//   originalContentBackground
//   setOriginalContentBackground:
//   nativeBackgrounds
//   setNativeBackgrounds:
//   backdrop
//   setBackdrop:
@end

@interface SXDockVisibilityState : NSObject
{
    BOOL _hidden;
    BOOL _interactive;
    CALayer * _originalMask;
    CALayer * _emptyMask;
}
@property(nonatomic, assign) BOOL hidden;
@property(nonatomic, assign) BOOL interactive;
@property(nonatomic, strong) CALayer * originalMask;
@property(nonatomic, strong) CALayer * emptyMask;
// Recovered selectors:
//   hidden
//   setHidden:
//   interactive
//   setInteractive:
//   originalMask
//   setOriginalMask:
//   emptyMask
//   setEmptyMask:
@end

@interface SXVerticalPanProxy : NSObject
{
    UIPanGestureRecognizer * _real;
}
@property(nonatomic, strong) UIPanGestureRecognizer * real;
// Recovered selectors:
//   state
//   view
//   translationInView:
//   velocityInView:
//   real
//   setReal:
@end

@interface SXLRegionCaptureService : NSObject
// Recovered selectors:
//   capture
@end

@interface SXLAppInfo : NSObject
{
    NSString * _bundleIdentifier;
    NSString * _displayName;
    UIImage * _icon;
    id _privateApplication;
}
@property(nonatomic, strong) NSString * bundleIdentifier;
@property(nonatomic, strong) NSString * displayName;
@property(nonatomic, strong) UIImage * icon;
@property(nonatomic, strong) id privateApplication;
// Recovered selectors:
//   bundleIdentifier
//   setBundleIdentifier:
//   displayName
//   setDisplayName:
//   icon
//   setIcon:
//   privateApplication
//   setPrivateApplication:
@end

@interface SXLAppCenter : NSObject
{
    BOOL _workspaceMapLoaded;
    NSMutableArray * _mutableApplications;
    NSMutableDictionary * _applicationMap;
    NSCache * _iconCache;
    id _applicationController;
}
@property(nonatomic, strong) NSMutableArray * mutableApplications;
@property(nonatomic, strong) NSMutableDictionary * applicationMap;
@property(nonatomic, strong) NSCache * iconCache;
@property(nonatomic, strong) id applicationController;
@property(nonatomic, assign) BOOL workspaceMapLoaded;
@property(nonatomic, strong) id installedApplications;
// Recovered selectors:
//   openBundleIDInZengNiu:mode:canCommit:completion:
//   ql_iconPipeline
//   requestIconForBundleID:size:completion:
//   requestIconForBundleID:size:isCurrent:completion:
//   invalidatePreparedIcons
//   init
//   installedApplications
//   reloadInstalledApplications
//   reloadFromApplicationWorkspace
//   ensureApplicationForBundleID:
//   iconForPrivateApplication:bundleID:
//   applicationForBundleID:
//   iconForBundleID:
//   launchBundleID:error:
//   openBundleIDInScreenCoreDuo:sourceRect:error:
//   openBundleIDInScreenCore:sourceRect:error:
//   openBundleIDInIya:mode:error:
//   openBundleIDInMyrtle:error:
//   openBundleIDInSVP:error:
//   openBundleIDInFV:error:
//   openBundleIDInOpenSplit:error:
//   openBundleIDInPullOverCard:error:
//   mutableApplications
//   setMutableApplications:
//   applicationMap
//   setApplicationMap:
//   iconCache
//   setIconCache:
//   applicationController
//   setApplicationController:
//   workspaceMapLoaded
//   setWorkspaceMapLoaded:
//   sharedCenter
@end

@interface SXLAppLaunchHistory : NSObject
{
    NSUInteger _nextRequest;
    NSMutableDictionary * _targets;
}
@property(nonatomic, assign) NSUInteger nextRequest;
@property(nonatomic, strong) NSMutableDictionary * targets;
// Recovered selectors:
//   init
//   beginRequest
//   isCurrentRequest:
//   recordBundleID:openMode:request:accepted:
//   bundleIDForOpenMode:
//   nextRequest
//   setNextRequest:
//   targets
//   setTargets:
//   sharedHistory
@end

@interface SXLAppSelectionCleaner : NSObject
{
    id _workspace;
    id _applicationProxyClass;
    NSMutableDictionary * _firstMissingTimes;
}
@property(nonatomic, strong) id workspace;
@property(nonatomic, strong) id applicationProxyClass;
@property(nonatomic, strong) NSMutableDictionary * firstMissingTimes;
// Recovered selectors:
//   init
//   initWithWorkspace:
//   initWithWorkspace:applicationProxyClass:
//   inventoryFromWorkspace:
//   cleanDefaults:additionalBundleIDs:atTime:
//   workspace
//   setWorkspace:
//   applicationProxyClass
//   setApplicationProxyClass:
//   firstMissingTimes
//   setFirstMissingTimes:
//   sharedCleaner
@end

@interface SXLAutoBrightnessService : NSObject
// Recovered selectors:
//   currentValue
//   applyValue:
@end

@interface SXLDisplayClientService : NSObject
// Recovered selectors:
//   clientForNightShift:
@end

@interface SXLIconConsumer : NSObject
{
    id _isCurrent;
    id _completion;
}
@property(nonatomic, strong) id isCurrent;
@property(nonatomic, strong) id completion;
// Recovered selectors:
//   isCurrent
//   setIsCurrent:
//   completion
//   setCompletion:
@end

@interface SXLIconRequest : NSObject
{
    NSString * _key;
    CGFloat _size;
    CGFloat _scale;
    NSMutableArray * _completions;
}
@property(nonatomic, strong) NSString * key;
@property(nonatomic, assign) CGFloat size;
@property(nonatomic, assign) CGFloat scale;
@property(nonatomic, strong) NSMutableArray * completions;
// Recovered selectors:
//   key
//   setKey:
//   size
//   setSize:
//   scale
//   setScale:
//   completions
//   setCompletions:
@end

@interface SXLIconPipeline : NSObject
{
    SXLAppCenter * _source;
    NSCache * _cache;
    NSCache * _originals;
    NSMutableDictionary * _requests;
    NSMutableDictionary * _waiting;
    NSMutableArray * _pending;
    NSOperationQueue * _decodeQueue;
    NSTimer * _pump;
    NSUInteger _revision;
}
@property(nonatomic, strong) SXLAppCenter * source;
@property(nonatomic, strong) NSCache * cache;
@property(nonatomic, strong) NSCache * originals;
@property(nonatomic, strong) NSMutableDictionary * requests;
@property(nonatomic, strong) NSMutableDictionary * waiting;
@property(nonatomic, strong) NSMutableArray * pending;
@property(nonatomic, strong) NSOperationQueue * decodeQueue;
@property(nonatomic, strong) NSTimer * pump;
@property(nonatomic, assign) NSUInteger revision;
// Recovered selectors:
//   init
//   dealloc
//   memoryWarning:
//   invalidate
//   finish:image:revision:
//   prepare:original:
//   pumpOne
//   request:size:isCurrent:completion:
//   source
//   setSource:
//   cache
//   setCache:
//   originals
//   setOriginals:
//   requests
//   setRequests:
//   waiting
//   setWaiting:
//   pending
//   setPending:
//   decodeQueue
//   setDecodeQueue:
//   pump
//   setPump:
//   revision
//   setRevision:
@end

@interface SXLLockStateMonitor : NSObject
{
    BOOL _locked;
    BOOL _running;
    NSInteger _token;
    id _stateChanged;
    NSTimer * _timer;
}
@property(nonatomic, assign) BOOL locked;
@property(nonatomic, assign) BOOL running;
@property(nonatomic, assign) NSInteger token;
@property(nonatomic, strong) NSTimer * timer;
@property(nonatomic, strong) id stateChanged;
// Recovered selectors:
//   init
//   start
//   systemStateChanged:
//   refresh
//   stop
//   dealloc
//   locked
//   setLocked:
//   stateChanged
//   setStateChanged:
//   running
//   setRunning:
//   token
//   setToken:
//   timer
//   setTimer:
@end

@interface SXLOverlayController : UIViewController
{
    BOOL _updatingGeometry;
    BOOL _hasGeometry;
    UIView * _contentView;
    UIWindow * _geometryWindow;
    id _layoutChanged;
    NSTimer * _geometryTimer;
    NSString * _geometryKey;
    id _contentSafeAreaInsets;
}
@property(nonatomic, strong) id contentSafeAreaInsets;
@property(nonatomic, strong) NSTimer * geometryTimer;
@property(nonatomic, assign) BOOL updatingGeometry;
@property(nonatomic, assign) BOOL hasGeometry;
@property(nonatomic, strong) NSString * geometryKey;
@property(nonatomic, strong) UIView * contentView;
@property(nonatomic, strong) UIWindow * geometryWindow;
@property(nonatomic, strong) id layoutChanged;
@property(nonatomic, strong) id displayedOrientation;
// Recovered selectors:
//   displayedOrientation
//   shouldAutorotate
//   supportedInterfaceOrientations
//   loadView
//   setContentView:
//   viewDidLayoutSubviews
//   viewSafeAreaInsetsDidChange
//   viewWillTransitionToSize:withTransitionCoordinator:
//   startMonitoring
//   stopMonitoring
//   dealloc
//   refreshGeometry
//   contentView
//   geometryWindow
//   setGeometryWindow:
//   layoutChanged
//   setLayoutChanged:
//   contentSafeAreaInsets
//   setContentSafeAreaInsets:
//   geometryTimer
//   setGeometryTimer:
//   updatingGeometry
//   setUpdatingGeometry:
//   hasGeometry
//   setHasGeometry:
//   geometryKey
//   setGeometryKey:
@end

@interface SXLRecentSystemSource : NSObject
// Recovered selectors:
//   executingBundleIDsFromBundleIDs:
//   readBundleIDs
@end

@interface SXLRecentApplications : NSObject
{
    BOOL _available;
    NSArray * _bundleIDs;
    NSArray * _executingBundleIDs;
    id _source;
    NSHashTable * _owners;
    NSHashTable * _executingOwners;
    NSTimer * _timer;
}
@property(nonatomic, strong) id source;
@property(nonatomic, strong) NSHashTable * owners;
@property(nonatomic, strong) NSHashTable * executingOwners;
@property(nonatomic, strong) NSTimer * timer;
@property(nonatomic, strong) NSArray * bundleIDs;
@property(nonatomic, strong) NSArray * executingBundleIDs;
@property(nonatomic, assign) BOOL available;
// Recovered selectors:
//   initWithSource:
//   setMonitoring:forOwner:
//   setMonitoring:executingOnly:forOwner:
//   refresh
//   bundleIDsSortedByLaunchCount
//   recordLaunchForBundleID:
//   updateSnapshotPostingChanges:
//   dealloc
//   bundleIDs
//   setBundleIDs:
//   executingBundleIDs
//   setExecutingBundleIDs:
//   available
//   setAvailable:
//   source
//   setSource:
//   owners
//   setOwners:
//   executingOwners
//   setExecutingOwners:
//   timer
//   setTimer:
//   sharedApplications
@end

@interface SXLRegionScreenshotController : SXLOverlayController
{
    UIImage * _image;
    UIImageView * _imageView;
    UIView * _selectionView;
    UIView * _toolbar;
    CAShapeLayer * _shade;
    UILabel * _hint;
    SXLLockStateMonitor * _lockMonitor;
    id _start;
    id _selection;
    id _lastBounds;
}
@property(nonatomic, strong) UIImage * image;
@property(nonatomic, strong) UIImageView * imageView;
@property(nonatomic, strong) UIView * selectionView;
@property(nonatomic, strong) UIView * toolbar;
@property(nonatomic, strong) CAShapeLayer * shade;
@property(nonatomic, strong) UILabel * hint;
@property(nonatomic, strong) id selection;
@property(nonatomic, strong) id lastBounds;
@property(nonatomic, strong) id start;
@property(nonatomic, strong) SXLLockStateMonitor * lockMonitor;
// Recovered selectors:
//   button:action:
//   viewDidLoad
//   layoutCapture
//   updateSelection
//   selectRegion:
//   croppedImage
//   copyRegion
//   shareRegion
//   close
//   image
//   setImage:
//   imageView
//   setImageView:
//   selectionView
//   setSelectionView:
//   toolbar
//   setToolbar:
//   shade
//   setShade:
//   hint
//   setHint:
//   selection
//   setSelection:
//   lastBounds
//   setLastBounds:
//   start
//   setStart:
//   lockMonitor
//   setLockMonitor:
@end

@interface SXLShortcutRunObserver : NSObject
{
    BOOL _replied;
    id _runner;
    id _completion;
    NSString * _identifier;
}
@property(nonatomic, strong) id runner;
@property(nonatomic, strong) id completion;
@property(nonatomic, strong) NSString * identifier;
@property(nonatomic, assign) BOOL replied;
// Recovered selectors:
//   reply:message:
//   workflowRunnerClient:didFinishRunningWorkflowWithOutput:error:cancelled:
//   runner
//   setRunner:
//   completion
//   setCompletion:
//   identifier
//   setIdentifier:
//   replied
//   setReplied:
@end

@interface SXLZengNiuPreparation : NSObject
{
    BOOL _finished;
    id _request;
    id _canCommit;
    id _completion;
    id _contextTimer;
}
@property(nonatomic, strong) id request;
@property(nonatomic, strong) id canCommit;
@property(nonatomic, strong) id completion;
@property(nonatomic, strong) id contextTimer;
@property(nonatomic, assign) BOOL finished;
// Recovered selectors:
//   finish:error:
//   ready:
//   request
//   setRequest:
//   canCommit
//   setCanCommit:
//   completion
//   setCompletion:
//   contextTimer
//   setContextTimer:
//   finished
//   setFinished:
@end

@interface SXModuleController : SXLOverlayController
{
    id _module;
    UIViewController * _moduleController;
    UIButton * _closeButton;
    SXLLockStateMonitor * _lockMonitor;
}
@property(nonatomic, strong) id module;
@property(nonatomic, strong) UIViewController * moduleController;
@property(nonatomic, strong) UIButton * closeButton;
@property(nonatomic, strong) SXLLockStateMonitor * lockMonitor;
// Recovered selectors:
//   viewDidLoad
//   close
//   module
//   setModule:
//   moduleController
//   setModuleController:
//   closeButton
//   setCloseButton:
//   lockMonitor
//   setLockMonitor:
@end

