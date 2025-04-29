cmake_minimum_required(VERSION 3.8)
project(px4_swarm_controller)

# Compiler options
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Find dependencies
find_package(ament_cmake REQUIRED)
find_package(ament_cmake_python REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclpy REQUIRED)
find_package(px4_msgs REQUIRED)
find_package(std_msgs REQUIRED)
find_package(yaml-cpp REQUIRED)
find_package(custom_msgs REQUIRED)
find_package(Eigen3 REQUIRED)

# Include directories
include_directories(include ${YAML_CPP_INCLUDE_DIRS})

# C++ Executables
add_executable(arming src/Arming.cpp)
ament_target_dependencies(arming rclcpp px4_msgs)

add_executable(waypoint src/ChangeWaypoint.cpp)
ament_target_dependencies(waypoint rclcpp px4_msgs)
target_link_libraries(waypoint ${YAML_CPP_LIBRARIES})

add_executable(weighted_topology_neighbors src/SwarmControllers/WeightedTopology/WeightedTopologyNeighbors.cpp)
ament_target_dependencies(weighted_topology_neighbors rclcpp px4_msgs custom_msgs Eigen3)

add_executable(weighted_topology_controller src/SwarmControllers/WeightedTopology/WeightedTopologyController.cpp)
ament_target_dependencies(weighted_topology_controller rclcpp px4_msgs std_msgs custom_msgs Eigen3)

# Install C++ targets
install(TARGETS
  arming
  waypoint
  weighted_topology_neighbors
  weighted_topology_controller
  DESTINATION lib/${PROJECT_NAME}
)

# Install Python package
ament_python_install_package(${PROJECT_NAME})

# Install Python executables
install(PROGRAMS
  px4_swarm_controller/simulation_gz_node.py
  DESTINATION lib/${PROJECT_NAME}
  RENAME simulation_gz_node  # <- REMOVE .py at install time!
)

# Install launch and config folders
install(DIRECTORY
  launch
  DESTINATION share/${PROJECT_NAME}
)

install(DIRECTORY
  config
  DESTINATION share/${PROJECT_NAME}
)

# Testing
if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
