import numpy as np
import skfuzzy as fuzz
from skfuzzy import control as ctrl
from app.soft_computing.executor import cpu_pool

class FuzzyCrowdInferenceSystem:
    def __init__(self):
        # Input Universe: Queue length [0, 50]
        self.queue_length = ctrl.Antecedent(np.arange(0, 51, 1), 'queue_length')
        # Input Universe: 15-minute order arrival velocity [0, 20 orders/min]
        self.order_velocity = ctrl.Antecedent(np.arange(0, 21, 0.5), 'order_velocity')
        # Output Universe: Crowd Index [0, 100%]
        self.crowd_index = ctrl.Consequent(np.arange(0, 101, 1), 'crowd_index')

        # Membership functions
        self.queue_length['LOW'] = fuzz.trapmf(self.queue_length.universe, [0, 0, 5, 12])
        self.queue_length['MEDIUM'] = fuzz.trimf(self.queue_length.universe, [8, 18, 28])
        self.queue_length['HIGH'] = fuzz.trapmf(self.queue_length.universe, [22, 35, 50, 50])

        self.order_velocity['SLOW'] = fuzz.trapmf(self.order_velocity.universe, [0, 0, 2, 5])
        self.order_velocity['MODERATE'] = fuzz.trimf(self.order_velocity.universe, [3, 7, 12])
        self.order_velocity['SURGE'] = fuzz.trapmf(self.order_velocity.universe, [9, 14, 20, 20])

        self.crowd_index['LOW'] = fuzz.trapmf(self.crowd_index.universe, [0, 0, 20, 35])
        self.crowd_index['MODERATE'] = fuzz.trimf(self.crowd_index.universe, [25, 50, 75])
        self.crowd_index['HIGH'] = fuzz.trapmf(self.crowd_index.universe, [65, 80, 100, 100])

        # Rule base
        r1 = ctrl.Rule(self.queue_length['LOW'] & self.order_velocity['SLOW'], self.crowd_index['LOW'])
        r2 = ctrl.Rule(self.queue_length['LOW'] & self.order_velocity['MODERATE'], self.crowd_index['LOW'])
        r3 = ctrl.Rule(self.queue_length['LOW'] & self.order_velocity['SURGE'], self.crowd_index['MODERATE'])
        r4 = ctrl.Rule(self.queue_length['MEDIUM'] & self.order_velocity['SLOW'], self.crowd_index['LOW'])
        r5 = ctrl.Rule(self.queue_length['MEDIUM'] & self.order_velocity['MODERATE'], self.crowd_index['MODERATE'])
        r6 = ctrl.Rule(self.queue_length['MEDIUM'] & self.order_velocity['SURGE'], self.crowd_index['HIGH'])
        r7 = ctrl.Rule(self.queue_length['HIGH'] & self.order_velocity['SLOW'], self.crowd_index['MODERATE'])
        r8 = ctrl.Rule(self.queue_length['HIGH'] & self.order_velocity['MODERATE'], self.crowd_index['HIGH'])
        r9 = ctrl.Rule(self.queue_length['HIGH'] & self.order_velocity['SURGE'], self.crowd_index['HIGH'])

        self.control_system = ctrl.ControlSystem([r1, r2, r3, r4, r5, r6, r7, r8, r9])

    def evaluate_sync(self, queue_val: float, velocity_val: float) -> dict:
        sim = ctrl.ControlSystemSimulation(self.control_system)
        sim.input['queue_length'] = max(0.0, min(50.0, float(queue_val)))
        sim.input['order_velocity'] = max(0.0, min(20.0, float(velocity_val)))
        sim.compute()

        score = float(sim.output['crowd_index'])
        if score < 35.0:
            level = "LOW"
            est_wait = max(3.0, queue_val * 1.5)
        elif score < 70.0:
            level = "MODERATE"
            est_wait = max(7.0, queue_val * 2.2)
        else:
            level = "HIGH"
            est_wait = max(15.0, queue_val * 3.5)

        return {
            "crowd_score": round(score, 1),
            "crowd_level": level,
            "estimated_wait_minutes": round(est_wait, 1)
        }

    async def evaluate_async(self, queue_val: float, velocity_val: float) -> dict:
        return await cpu_pool.run(self.evaluate_sync, queue_val, velocity_val)

fuzzy_engine = FuzzyCrowdInferenceSystem()
