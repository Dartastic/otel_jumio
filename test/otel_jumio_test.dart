// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_jumio/otel_jumio.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_jumio-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('workflow_executions records capabilities + id type', () async {
    await tracedJumio<String>(
      operation: 'workflow_executions.get',
      dataCenter: 'EU',
      invoke: () async => const JumioCallResult(
        value: 'ok',
        result: JumioResult(
          accountId: 'a-1',
          workflowExecutionId: 'wf-1',
          status: 'PROCESSED',
          decision: 'PASSED',
          workflowDefinitionId: 10015,
          capabilitiesUsed: 'extraction,liveness,similarity,dataChecks',
          idType: 'PASSPORT',
          usabilityScore: 92,
          dataCenter: 'EU',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('jumio workflow_executions.get')!);
    expect(a['jumio.workflow_execution.id'], 'wf-1');
    expect(a['jumio.decision'], 'PASSED');
    expect(
        a['jumio.capabilities'], 'extraction,liveness,similarity,dataChecks');
    expect(a['jumio.id.type'], 'PASSPORT');
    expect(a['jumio.usability.score'], 92);
    expect(a['jumio.data_center'], 'EU');
  });

  test('REJECTED sets span error', () async {
    await tracedJumio<String>(
      operation: 'workflow_executions.get',
      invoke: () async => const JumioCallResult(
        value: 'ok',
        result: JumioResult(decision: 'REJECTED'),
      ),
    );
    expect(
      spans.findSpanByName('jumio workflow_executions.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutJumioInstrumentationAsync(() async {
      await tracedJumio<String>(
        operation: 'accounts.create',
        invoke: () async => const JumioCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('jumio '), isEmpty);
  });
}
