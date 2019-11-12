import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'common.dart';

class Context extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

BuildContext get context => find.byType(Context).evaluate().single;

T of<T>([BuildContext c]) => Provider.of<T>(c ?? context, listen: false);

void main() {
  group('InheritedProvider.value()', () {
    testWidgets('pass down current value', (tester) async {
      int value;
      final child = Consumer<int>(
        builder: (_, v, __) {
          value = v;
          return Container();
        },
      );

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );

      expect(value, equals(42));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 43, child: child),
      );

      expect(value, equals(43));
    });
    testWidgets('default updateShouldNotify', (tester) async {
      var buildCount = 0;

      final child = Consumer<int>(builder: (_, __, ___) {
        buildCount++;
        return Container();
      });

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );
      expect(buildCount, equals(1));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );
      expect(buildCount, equals(1));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 43, child: child),
      );
      expect(buildCount, equals(2));
    });
    testWidgets('custom updateShouldNotify', (tester) async {
      var buildCount = 0;
      final updateShouldNotify = UpdateShouldNotifyMock<int>();

      final child = Consumer<int>(builder: (_, __, ___) {
        buildCount++;
        return Container();
      });

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(1));
      verifyZeroInteractions(updateShouldNotify);

      when(updateShouldNotify(any, any)).thenReturn(false);
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 43,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(1));
      verify(updateShouldNotify(42, 43))..called(1);

      when(updateShouldNotify(any, any)).thenReturn(true);
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 44,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(2));
      verify(updateShouldNotify(43, 44))..called(1);

      verifyNoMoreInteractions(updateShouldNotify);
    });
  });
  group('InheritedProvider()', () {
    testWidgets(
      'fails if initialValueBuilder calls inheritFromElement/inheritFromWiggetOfExactType',
      (tester) async {
        await tester.pumpWidget(
          InheritedProvider<int>.value(
            value: 42,
            child: InheritedProvider<double>(
              initialValueBuilder: (context) =>
                  Provider.of<int>(context).toDouble(),
              child: Consumer<double>(
                builder: (_, __, ___) => Container(),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
    );
    testWidgets(
      'builder is called on every rebuild'
      'and after a dependency change',
      (tester) async {
        int lastValue;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            return Container();
          },
        );
        final valueBuilder = ValueBuilderMock<int>();
        when(valueBuilder(any, any))
            .thenAnswer((i) => (i.positionalArguments[1] as int) * 2);

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => 42,
            valueBuilder: valueBuilder,
            child: Container(),
          ),
        );

        final inheritedElement = tester.element(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>),
        );
        verifyZeroInteractions(valueBuilder);

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => 42,
            valueBuilder: valueBuilder,
            child: child,
          ),
        );

        verify(valueBuilder(inheritedElement, 42)).called(1);
        expect(lastValue, equals(84));

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => 42,
            valueBuilder: valueBuilder,
            child: child,
          ),
        );

        verify(valueBuilder(inheritedElement, 84)).called(1);
        expect(lastValue, equals(168));

        verifyNoMoreInteractions(valueBuilder);
      },
    );
    testWidgets(
      'builder calls updateShouldNotify & use == if missing',
      (tester) async {
        int lastValue;
        var buildCount = 0;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            buildCount++;
            return Container();
          },
        );

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 42,
            child: child,
          ),
        );

        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 42,
            child: child,
          ),
        );

        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 43,
            child: child,
          ),
        );

        expect(lastValue, equals(43));
        expect(buildCount, equals(2));
      },
    );
    testWidgets(
      'builder calls updateShouldNotify callback',
      (tester) async {
        final updateShouldNotify = UpdateShouldNotifyMock<int>();

        int lastValue;
        var buildCount = 0;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            buildCount++;
            return Container();
          },
        );

        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 42,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verifyZeroInteractions(updateShouldNotify);
        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        when(updateShouldNotify(any, any)).thenReturn(true);
        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 42,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verify(updateShouldNotify(42, 42)).called(1);
        expect(lastValue, equals(42));
        expect(buildCount, equals(2));

        when(updateShouldNotify(any, any)).thenReturn(false);
        await tester.pumpWidget(
          InheritedProvider<int>(
            initialValueBuilder: (_) => null,
            valueBuilder: (_, __) => 43,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verify(updateShouldNotify(42, 43)).called(1);
        expect(lastValue, equals(42));
        expect(buildCount, equals(2));

        verifyNoMoreInteractions(updateShouldNotify);
      },
    );
    testWidgets('initialValue is transmitted to valueBuilder', (tester) async {
      int lastValue;
      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: (_) => 0,
          valueBuilder: (_, last) {
            lastValue = last;
            return 42;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      expect(lastValue, equals(0));
    });
    testWidgets('calls builder again if dependencies change', (tester) async {
      final valueBuilder = ValueBuilderMock<int>();

      when(valueBuilder(any, any)).thenAnswer((invocation) {
        return int.parse(Provider.of<String>(
          invocation.positionalArguments.first as BuildContext,
        ));
      });

      var buildCount = 0;
      final child = InheritedProvider<int>(
        initialValueBuilder: (_) => 0,
        valueBuilder: valueBuilder,
        child: Consumer<int>(
          builder: (_, value, __) {
            buildCount++;
            return Text(
              value.toString(),
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '42',
          child: child,
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('42'), findsOneWidget);

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '24',
          child: child,
        ),
      );

      expect(buildCount, equals(2));
      expect(find.text('24'), findsOneWidget);

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '24',
          child: child,
          updateShouldNotify: (_, __) => true,
        ),
      );

      expect(buildCount, equals(2));
      expect(find.text('24'), findsOneWidget);
    });
    testWidgets('exposes initialValue if valueBuilder is null', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: (_) => 42,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
    });
    testWidgets('call dispose on unmount', (tester) async {
      final dispose = DisposerMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 42,
          dispose: dispose,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));

      verifyZeroInteractions(dispose);

      BuildContext context = tester
          .element(find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      await tester.pumpWidget(Container());

      verify(dispose(context, 42)).called(1);
      verifyNoMoreInteractions(dispose);
    });
    testWidgets('switching between builder and value correctly update/dispose',
        (tester) async {
      final dispose1 = DisposerMock<int>();
      final initialBuilder1 = InitialValueBuilderMock<int>(42);
      final valueBuilder1 = ValueBuilderMock<int>(0);

      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: initialBuilder1,
          valueBuilder: valueBuilder1,
          dispose: dispose1,
          child: const TextOf<int>(),
        ),
      );

      final context = tester
          .element(find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      expect(find.text('0'), findsOneWidget);
      verify(initialBuilder1(context));
      verify(valueBuilder1(context, 42));
      verifyNoMoreInteractions(initialBuilder1);
      verifyNoMoreInteractions(valueBuilder1);
      verifyZeroInteractions(dispose1);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 1,
          child: const TextOf<int>(),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      verify(dispose1(context, 0)).called(1);
      verifyNoMoreInteractions(dispose1);
      verifyNoMoreInteractions(initialBuilder1);
      verifyNoMoreInteractions(valueBuilder1);

      final dispose2 = DisposerMock<int>();
      final initialBuilder2 = InitialValueBuilderMock<int>(42);
      final valueBuilder2 = ValueBuilderMock<int>(2);

      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: initialBuilder2,
          valueBuilder: valueBuilder2,
          dispose: dispose2,
          child: const TextOf<int>(),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      verify(initialBuilder2(context));
      verify(valueBuilder2(context, 42));
      verifyNoMoreInteractions(initialBuilder2);
      verifyNoMoreInteractions(valueBuilder2);
      verifyZeroInteractions(dispose2);
    });
    testWidgets(
        '.value to builder without initialBuilder, initialvalue is null',
        (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 1,
          child: const TextOf<int>(),
        ),
      );

      int previousValue;

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, prev) => previousValue = prev,
          child: const TextOf<int>(),
        ),
      );

      expect(previousValue, isNull);
    });
    testWidgets('builder to .value, dispose not called if value never read',
        (tester) async {
      final dispose = DisposerMock<int>();

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 42,
          dispose: dispose,
          child: Container(),
        ),
      );

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 1,
          child: const TextOf<int>(),
        ),
      );

      verifyZeroInteractions(dispose);
    });
    testWidgets('builder unmount, dispose not called if value never read',
        (tester) async {
      final dispose = DisposerMock<int>();

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 42,
          dispose: dispose,
          child: Container(),
        ),
      );

      await tester.pumpWidget(Container());

      verifyZeroInteractions(dispose);
    });
    testWidgets('call dispose after new value', (tester) async {
      // TODO: call new dispose instead of previous dispose
      final dispose = DisposerMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 42,
          dispose: dispose,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 42,
          dispose: dispose,
          child: Container(),
        ),
      );

      verifyZeroInteractions(dispose);

      BuildContext context = tester
          .element(find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, __) => 24,
          dispose: dispose,
          child: Container(),
        ),
      );

      verify(dispose(context, 42)).called(1);
      verifyNoMoreInteractions(dispose);
    });

    testWidgets('valueBuilder works without initialBuilder', (tester) async {
      int lastValue;
      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, last) {
            lastValue = last;
            return 42;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      expect(lastValue, equals(null));

      await tester.pumpWidget(
        InheritedProvider<int>(
          valueBuilder: (_, last) {
            lastValue = last;
            return 24;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(24));
      expect(lastValue, equals(42));
    });
    test('throws if both builder and initialBuilder are missing', () {
      expect(
        () => InheritedProvider<int>(child: Container()),
        throwsAssertionError,
      );
    });
    testWidgets('calls initialValueBuilder lazily once', (tester) async {
      final initialValueBuilder = InitialValueBuilderMock<int>();
      when(initialValueBuilder(any)).thenReturn(42);

      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: initialValueBuilder,
          child: Context(),
        ),
      );

      verifyZeroInteractions(initialValueBuilder);

      final inheritedProviderElement = tester.element(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>),
      );

      expect(of<int>(), equals(42));
      verify(initialValueBuilder(inheritedProviderElement)).called(1);

      await tester.pumpWidget(
        InheritedProvider<int>(
          initialValueBuilder: initialValueBuilder,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      verifyNoMoreInteractions(initialValueBuilder);
    });
  });

  testWidgets('builder startListening', (tester) async {
    final stopListening = StopListeningMock();
    final startListening = StartListeningMock<int>(stopListening);
    final dispose = DisposerMock<int>();

    await tester.pumpWidget(
      InheritedProvider<int>(
        valueBuilder: (_, __) => 42,
        startListening: startListening,
        dispose: dispose,
        child: const TextOf<int>(),
      ),
    );

    final element = tester.element<InheritedProviderElement<int>>(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>));

    verify(startListening(element, 42)).called(1);
    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);
    verifyZeroInteractions(dispose);

    await tester.pumpWidget(
      InheritedProvider<int>(
        valueBuilder: (_, __) => 42,
        startListening: startListening,
        dispose: dispose,
        child: const TextOf<int>(),
      ),
    );

    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);
    verifyZeroInteractions(dispose);

    await tester.pumpWidget(Container());

    verifyNoMoreInteractions(startListening);
    verifyInOrder([
      stopListening(),
      dispose(element, 42),
    ]);
    verifyNoMoreInteractions(dispose);
    verifyNoMoreInteractions(stopListening);
  });
  testWidgets('.value startListening', (tester) async {
    final stopListening = StopListeningMock();
    final startListening = StartListeningMock<int>(stopListening);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 42,
        startListening: startListening,
        child: Container(),
      ),
    );

    verifyZeroInteractions(startListening);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 42,
        startListening: startListening,
        child: const TextOf<int>(),
      ),
    );

    final element = tester.element<InheritedProviderElement<int>>(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>));

    verify(startListening(element, 42)).called(1);
    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 42,
        startListening: startListening,
        child: const TextOf<int>(),
      ),
    );

    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);

    await tester.pumpWidget(Container());

    verifyNoMoreInteractions(startListening);
    verify(stopListening()).called(1);
  });
  testWidgets(
      'builder startListening called again when valueBuilder returns new value',
      (tester) async {
    final stopListening = StopListeningMock();
    final startListening = StartListeningMock<int>(stopListening);

    await tester.pumpWidget(
      InheritedProvider<int>(
        valueBuilder: (_, __) => 42,
        startListening: startListening,
        child: const TextOf<int>(),
      ),
    );

    final element = tester.element<InheritedProviderElement<int>>(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>));

    verify(startListening(element, 42)).called(1);
    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);

    final stopListening2 = StopListeningMock();
    final startListening2 = StartListeningMock<int>(stopListening2);

    await tester.pumpWidget(
      InheritedProvider<int>(
        valueBuilder: (_, __) => 24,
        startListening: startListening2,
        child: const TextOf<int>(),
      ),
    );

    verifyNoMoreInteractions(startListening);
    verifyInOrder([
      stopListening(),
      startListening2(element, 24),
    ]);
    verifyNoMoreInteractions(startListening2);
    verifyZeroInteractions(stopListening2);

    await tester.pumpWidget(Container());

    verifyNoMoreInteractions(startListening);
    verify(stopListening2()).called(1);
  });
  testWidgets(
      'value startListening called again when valueBuilder returns new value',
      (tester) async {
    final stopListening = StopListeningMock();
    final startListening = StartListeningMock<int>(stopListening);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 42,
        startListening: startListening,
        child: const TextOf<int>(),
      ),
    );

    final element = tester.element<InheritedProviderElement<int>>(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>));

    verify(startListening(element, 42)).called(1);
    verifyNoMoreInteractions(startListening);
    verifyZeroInteractions(stopListening);

    final stopListening2 = StopListeningMock();
    final startListening2 = StartListeningMock<int>(stopListening2);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 24,
        startListening: startListening2,
        child: const TextOf<int>(),
      ),
    );

    verifyNoMoreInteractions(startListening);
    verifyInOrder([
      stopListening(),
      startListening2(element, 24),
    ]);
    verifyNoMoreInteractions(startListening2);
    verifyZeroInteractions(stopListening2);

    await tester.pumpWidget(Container());

    verifyNoMoreInteractions(startListening);
    verify(stopListening2()).called(1);
  });
  // TODO: stopListening not called twice if rebuild doesn't have listeners

  testWidgets('startListening markNeedsNotifyDependents', (tester) async {
    InheritedProviderElement<int> element;
    var buildCount = 0;

    await tester.pumpWidget(
      InheritedProvider<int>(
        valueBuilder: (_, __) => 24,
        startListening: (e, value) {
          element = e;
          return () {};
        },
        child: Consumer<int>(
          builder: (_, __, ___) {
            buildCount++;
            return Container();
          },
        ),
      ),
    );

    expect(buildCount, equals(1));

    element.markNeedsNotifyDependents();
    await tester.pump();

    expect(buildCount, equals(2));

    await tester.pump();

    expect(buildCount, equals(2));
  });
  // TODO: value to builder & reverse does notify dependents
  // TODO: removeListener cannot be null
  // TODO: _debugCheckInvalidValueType
}