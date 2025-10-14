import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../data/repos.dart';
import '../domain/time_service.dart';
import '../domain/scheduler_service.dart';

final dbProvider = Provider<AppDb>((ref) => AppDb());

final taskRepoProvider = Provider<TaskRepo>((ref) => TaskRepo(ref.read(dbProvider)));
final reminderRepoProvider = Provider<ReminderRepo>((ref) => ReminderRepo(ref.read(dbProvider)));

final timeServiceProvider = Provider<TimeService>((ref) => TimeService());
final schedulerProvider = Provider<SchedulerService>((ref) => SchedulerService(ref.read(timeServiceProvider)));