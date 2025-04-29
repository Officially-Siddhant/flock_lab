# Author: Siddhant Baroth, New York University, 2025

import os
from glob import glob
from setuptools import setup

package_name = 'px4_swarm_controller'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('px4_swarm_controller/launch/*.launch.py')),  # Install launch files!
        (os.path.join('share', package_name, 'config'), glob('px4_swarm_controller/config/*')),  # Install config files too if needed
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Your Name',
    maintainer_email='your@email.com',
    description='PX4 Swarm Controller for Gazebo Classic and Harmonic',
    license='Apache License 2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'simulation_gz_node = px4_swarm_controller.simulation_gz_node:main',
        ],
    },
)
