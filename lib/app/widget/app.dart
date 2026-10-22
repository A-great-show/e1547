import 'package:e1547/account/account.dart';
import 'package:e1547/app/app.dart';
import 'package:e1547/app/widget/initialize.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/logs/logs.dart';
import 'package:e1547/onboarding/onboarding.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/task/task.dart';
import 'package:e1547/user/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_sub/flutter_sub.dart';
import 'package:relative_time/relative_time.dart';

/// Simplified Chinese, preferred whenever every registered delegate can serve
/// it. `RelativeTimeLocalizations` gets its translations from CLDR, so this is
/// checked at runtime instead of assumed: if a dependency ever drops zh, the
/// app simply keeps following the platform locale.
const Locale _zhCN = Locale('zh', 'CN');

final Locale? _chineseLocale =
    RelativeTimeLocalizations.delegate.isSupported(_zhCN) ? _zhCN : null;

final List<Locale> _supportedLocales = [
  if (_chineseLocale != null) _chineseLocale,
  const Locale('en', 'US'),
];

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AppInit(
      child: MultiProvider(
        providers: [
          const WindowProvider(),
          AppInfoClientProvider(),
          ClientFactoryProvider(),
          SettingsProvider(),
          VideoServiceProvider(),
          AdaptiveScaffoldScope(),
          DefaultRouteObserver(),
          NavigationProvider(
            destinations: rootDestintations,
            drawerHeader: (context) => const UserDrawerHeader(),
          ),
        ],
        builder: (context, child) => LogLevelScope(
          child: ValueListenableBuilder<AppTheme>(
            valueListenable: context.watch<Settings>().theme,
            builder: (context, value, child) => ExcludeSemantics(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value:
                    value.data.appBarTheme.systemOverlayStyle ??
                    const SystemUiOverlayStyle(),
                child: SubValue<GlobalKey<NavigatorState>>(
                  create: () => GlobalKey<NavigatorState>(),
                  builder: (context, navigatorKey) => MaterialApp(
                    title: AppInfo.instance.appName,
                    theme: value.data,
                    locale: _chineseLocale,
                    supportedLocales: _supportedLocales,
                    scrollBehavior: AndroidStretchScrollBehaviour(),
                    localizationsDelegates: const [
                      GlobalWidgetsLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                      RelativeTimeLocalizations.delegate,
                    ],
                    navigatorKey: navigatorKey,
                    navigatorObservers: [
                      context.watch<AnyRouteObserver>(),
                      RouteLoggerObserver(),
                    ],
                    routes: context.watch<RouterDrawerController>().routes,
                    builder: (context, child) => WindowFrame(
                      child: WindowShortcuts(
                        navigatorKey: navigatorKey,
                        child: SecureDisplay(
                          child: LockScreen(
                            child: LoadingShell(
                              child: MultiProvider(
                                providers: [
                                  IdentityClientProvider(),
                                  TraitsClientProvider(),
                                  ClientProvider(),
                                  FileCacheProvider(),
                                  TasksControllerProvider(),
                                ],
                                child: LoadingCore(
                                  child: OnboardingGate(
                                    child: AccountConnector(
                                      navigatorKey: navigatorKey,
                                      child: FollowConnector(
                                        navigatorKey: navigatorKey,
                                        child: AppLinkHandler(
                                          navigatorKey: navigatorKey,
                                          child: NotificationHandler(
                                            navigatorKey: navigatorKey,
                                            child: AppBubbleOverlay(
                                              navigatorKey: navigatorKey,
                                              child: child!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
