import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<({String title, IconData icon})> destinations = [
    (title: 'Dashboard', icon: Icons.dashboard_outlined),
    (title: 'New Job', icon: Icons.add_box_outlined),
    (title: 'Excel Data', icon: Icons.table_chart_outlined),
    (title: 'Barcode', icon: Icons.qr_code_2_outlined),
    (title: 'Layout', icon: Icons.dashboard_customize_outlined),
    (title: 'PDF Preview', icon: Icons.picture_as_pdf_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4938CC), Color(0xFF8734D8), Color(0xFFD32383)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 16, 35),
            child: Text(
              'OMR PDF\nGenerator',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Material(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      selected: selected,
                      leading: Icon(
                        destination.icon,
                        color: Colors.white,
                        size: 21,
                      ),
                      title: Text(
                        destination.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
                );
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Offline · Desktop Application',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
