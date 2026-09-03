import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitbit_health_dashboard/core/models/user_goals.dart';
import 'package:fitbit_health_dashboard/features/goals/cubit/goals_cubit.dart';
import 'package:fitbit_health_dashboard/features/goals/cubit/goals_state.dart';

void main() {
  group('GoalsCubit', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('initial state is GoalsLoaded with default goals when uid is null', () {
      final cubit = GoalsCubit(firestore: fakeFirestore, uid: null);
      expect(cubit.state, const GoalsLoaded(UserGoals.defaultGoals));
      cubit.close();
    });

    test('updateGoals updates state immediately and writes to Firestore', () async {
      const testUid = 'user_123';
      final cubit = GoalsCubit(firestore: fakeFirestore, uid: testUid);

      const customGoals = UserGoals(
        stepGoal: 15000,
        calorieGoal: 2500,
        sleepHoursGoal: 8.5,
        activeMinutesGoal: 60,
      );

      await cubit.updateGoals(customGoals);

      expect(cubit.state, const GoalsLoaded(customGoals));

      final doc = await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('settings')
          .doc('goals')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['stepGoal'], 15000);
      expect(doc.data()?['calorieGoal'], 2500);

      await cubit.close();
    });
  });
}
