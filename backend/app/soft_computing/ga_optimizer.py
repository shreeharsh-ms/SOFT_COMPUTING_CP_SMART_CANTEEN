import numpy as np
from typing import List, Dict, Any
from app.soft_computing.executor import cpu_pool

class KitchenResourceGA:
    def __init__(
        self,
        menu_items: List[Dict[str, Any]],
        total_kitchen_capacity_minutes: float = 360.0,
        population_size: int = 40,
        generations: int = 50,
        mutation_rate: float = 0.15
    ):
        self.menu_items = menu_items
        self.num_items = len(menu_items)
        self.capacity = total_kitchen_capacity_minutes
        self.pop_size = population_size
        self.generations = generations
        self.mutation_rate = mutation_rate

    def _fitness(self, individual: np.ndarray) -> float:
        total_prep_time = sum(individual[i] * self.menu_items[i]["prep_time"] for i in range(self.num_items))
        if total_prep_time > self.capacity:
            penalty = (total_prep_time - self.capacity) * 20.0
            return max(0.001, 100.0 - penalty)

        expected_profit = 0.0
        for i in range(self.num_items):
            demand = self.menu_items[i]["demand"]
            produced = individual[i]
            sold = min(produced, demand)
            unsold = max(0, produced - demand)
            expected_profit += (sold * self.menu_items[i]["profit"]) - (unsold * self.menu_items[i]["wastage_cost"])

        return max(1.0, expected_profit + 500.0)

    def optimize_sync(self) -> Dict[str, Any]:
        if self.num_items == 0:
            return {"optimized_plan": [], "expected_profit": 0.0}

        population = []
        for _ in range(self.pop_size):
            chromosome = np.array([
                np.random.randint(max(5, int(item["demand"] * 0.5)), int(item["demand"] * 1.5) + 2)
                for item in self.menu_items
            ])
            population.append(chromosome)

        for _ in range(self.generations):
            fitness_scores = np.array([self._fitness(ind) for ind in population])
            total_fit = np.sum(fitness_scores)
            probs = fitness_scores / (total_fit if total_fit > 0 else 1.0)

            selected_idx = np.random.choice(self.pop_size, size=self.pop_size, p=probs)
            new_population = []

            for i in range(0, self.pop_size, 2):
                p1, p2 = population[selected_idx[i]], population[selected_idx[(i + 1) % self.pop_size]]
                mask = np.random.rand(self.num_items) < 0.5
                c1 = np.where(mask, p1, p2)
                c2 = np.where(mask, p2, p1)

                if np.random.rand() < self.mutation_rate:
                    mut_gene = np.random.randint(0, self.num_items)
                    c1[mut_gene] = max(0, c1[mut_gene] + np.random.randint(-3, 4))
                if np.random.rand() < self.mutation_rate:
                    mut_gene = np.random.randint(0, self.num_items)
                    c2[mut_gene] = max(0, c2[mut_gene] + np.random.randint(-3, 4))

                new_population.extend([c1, c2])
            population = new_population[:self.pop_size]

        final_fitness = [self._fitness(ind) for ind in population]
        best_idx = int(np.argmax(final_fitness))
        best_chromosome = population[best_idx]

        plan = []
        for i in range(self.num_items):
            plan.append({
                "item_name": self.menu_items[i]["name"],
                "recommended_prep_batch": int(best_chromosome[i]),
                "estimated_demand": self.menu_items[i]["demand"]
            })

        return {
            "optimized_plan": plan,
            "fitness_score": float(final_fitness[best_idx])
        }

    async def optimize_async(self) -> Dict[str, Any]:
        return await cpu_pool.run(self.optimize_sync)
