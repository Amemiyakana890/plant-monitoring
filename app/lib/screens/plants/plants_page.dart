import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../data/dummy_plants.dart';

class PlantsPage extends StatelessWidget {
  const PlantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,

      child: ListView(
        padding: const EdgeInsets.all(16),

        children: [

          const Text(
            "植物管理",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton.icon(

              icon: const Icon(Icons.add),

              label: const Text("植物を追加"),

              onPressed: () {

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("植物追加画面（今後実装予定）"),
                  ),
                );

              },
            ),
          ),

          const SizedBox(height: 24),

          ...dummyPlants.map(
            (plant) => Padding(
              padding: const EdgeInsets.only(bottom: 16),

              child: Card(
                color: AppColors.surface,

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Row(
                        children: [

                          const Icon(
                            Icons.local_florist,
                            color: AppColors.primary,
                          ),

                          const SizedBox(width: 8),

                          Text(
                            plant.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        ],
                      ),

                      const SizedBox(height: 8),

                      Text("センサーID : ATOM-00${plant.id}"),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,

                        children: [

                          OutlinedButton.icon(

                            icon: const Icon(Icons.edit),

                            label: const Text("編集"),

                            onPressed: () {

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("${plant.name} 編集（今後実装予定）"),
                                ),
                              );

                            },

                          ),

                          const SizedBox(width: 12),

                          ElevatedButton.icon(

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),

                            icon: const Icon(Icons.delete),

                            label: const Text("削除"),

                            onPressed: () {

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("${plant.name} 削除（今後実装予定）"),
                                ),
                              );

                            },

                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
