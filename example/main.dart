// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_jumio/otel_jumio.dart';

/// Traces Jumio KYX calls with OpenTelemetry.
///
/// `otel_jumio` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Jumio KYX call in
/// [tracedJumio]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'jumio-example');

  // Wraps a Jumio KYX API call in a CLIENT span.
  final jumioId = await tracedJumio<String>(
    operation: 'accounts.create',
    dataCenter: 'example',
    invoke: () async {
      // Make the Jumio KYX call here, then report what it returned.
      const id = 'jumio_8f3a2c';
      return const JumioCallResult(
          value: id,
          result: JumioResult(
              accountId: 'account_8f3a2c',
              workflowExecutionId: 'workflowexecution_8f3a2c',
              status: 'INITIATED',
              decision: 'PASSED',
              workflowDefinitionId: 1,
              capabilitiesUsed: 'extraction',
              idType: 'ID_CARD',
              usabilityScore: 1,
              dataCenter: 'US',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedJumio accounts.create returned $jumioId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutJumioInstrumentationAsync.
  await runWithoutJumioInstrumentationAsync(
    () => tracedJumio<String>(
      operation: 'accounts.create',
      dataCenter: 'example',
      invoke: () async {
        const id = 'jumio_8f3a2c';
        return const JumioCallResult(
            value: id,
            result: JumioResult(
                accountId: 'account_8f3a2c',
                workflowExecutionId: 'workflowexecution_8f3a2c',
                status: 'INITIATED',
                decision: 'PASSED',
                workflowDefinitionId: 1,
                capabilitiesUsed: 'extraction',
                idType: 'ID_CARD',
                usabilityScore: 1,
                dataCenter: 'US',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
