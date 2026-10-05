import numpy as np
from typing import List, Dict, Any
from app.soft_computing.executor import cpu_pool

class KitchenPSOScheduler:
    def __init__(self, orders: List[Dict[str, Any]], num_particles: int = 30, iterations: int = 40):
        self.orders = orders
        self.n_orders = len(orders)
        self.num_particles = num_particles
        self.iterations = iterations

    def _calculate_makespan(self, sequence_indices: np.ndarray) -> float:
        current_time = 0.0
        total_waiting_penalty = 0.0
        for idx in sequence_indices:
            prep_time = self.orders[int(idx)]["prep_time"]
            current_time += prep_time
            total_waiting_penalty += current_time
        return total_waiting_penalty

    def schedule_sync(self) -> Dict[str, Any]:
        if self.n_orders <= 1:
            return {
                "optimized_queue": [o["token"] for o in self.orders],
                "expected_makespan": sum(o["prep_time"] for o in self.orders)
            }

        particles = np.random.rand(self.num_particles, self.n_orders)
        velocities = (np.random.rand(self.num_particles, self.n_orders) - 0.5) * 0.1

        personal_best_pos = np.copy(particles)
        personal_best_scores = np.zeros(self.num_particles)

        for i in range(self.num_particles):
            order_seq = np.argsort(particles[i])
            personal_best_scores[i] = self._calculate_makespan(order_seq)

        global_best_idx = np.argmin(personal_best_scores)
        global_best_pos = np.copy(personal_best_pos[global_best_idx])
        global_best_score = personal_best_scores[global_best_idx]

        w = 0.7
        c1 = 1.4
        c2 = 1.4

        for _ in range(self.iterations):
            for i in range(self.num_particles):
                r1, r2 = np.random.rand(self.n_orders), np.random.rand(self.n_orders)
                velocities[i] = (
                    w * velocities[i] +
                    c1 * r1 * (personal_best_pos[i] - particles[i]) +
                    c2 * r2 * (global_best_pos - particles[i])
                )
                particles[i] = np.clip(particles[i] + velocities[i], 0.0, 1.0)

                seq = np.argsort(particles[i])
                current_score = self._calculate_makespan(seq)

                if current_score < personal_best_scores[i]:
                    personal_best_scores[i] = current_score
                    personal_best_pos[i] = np.copy(particles[i])

                    if current_score < global_best_score:
                        global_best_score = current_score
                        global_best_pos = np.copy(particles[i])

        optimal_sequence = np.argsort(global_best_pos)
        sorted_orders = [self.orders[int(idx)]["token"] for idx in optimal_sequence]

        return {
            "optimized_queue": sorted_orders,
            "expected_makespan": float(global_best_score)
        }

    async def schedule_async(self) -> Dict[str, Any]:
        return await cpu_pool.run(self.schedule_sync)
