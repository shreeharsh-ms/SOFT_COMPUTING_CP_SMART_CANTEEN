from app.soft_computing.fuzzy_crowd import fuzzy_engine
from app.soft_computing.ga_optimizer import KitchenResourceGA
from typing import List, Dict, Any

class HybridDecisionEngine:
    @staticmethod
    async def compute_surge_preparation_advisory_async(
        people_count: int,
        active_orders: int,
        avg_wait: float,
        base_demand_items: List[Dict[str, Any]],
        cook_capacity: float = 360.0
    ) -> Dict[str, Any]:
        crowd_eval = await fuzzy_engine.evaluate_async(
            queue_val=float(active_orders),
            velocity_val=max(1.0, float(people_count) / 10.0)
        )

        crowd_multiplier = 1.0
        if crowd_eval["crowd_level"] == "HIGH":
            crowd_multiplier = 1.45
        elif crowd_eval["crowd_level"] == "MODERATE":
            crowd_multiplier = 1.15

        surge_items = []
        for item in base_demand_items:
            surge_items.append({
                "name": item["name"],
                "demand": int(item["demand"] * crowd_multiplier),
                "prep_time": item["prep_time"],
                "profit": item["profit"],
                "wastage_cost": item["wastage_cost"]
            })

        ga = KitchenResourceGA(
            menu_items=surge_items,
            total_kitchen_capacity_minutes=cook_capacity
        )
        ga_res = await ga.optimize_async()

        return {
            "crowd_analysis": crowd_eval,
            "demand_multiplier": crowd_multiplier,
            "recommended_preparation": ga_res["optimized_plan"]
        }
