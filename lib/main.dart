import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'features/claim/presentation/providers/claim_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BlocProvider<ClaimCubit>(
      create: (_) => ClaimCubit(createClaimAnalysisService()),
      child: const SathiApp(),
    ),
  );
}
