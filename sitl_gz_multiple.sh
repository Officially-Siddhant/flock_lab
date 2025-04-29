#!/bin/bash
set -e
# --------------------------------------------------
# PX4 SITL Multi-Agent Launcher for Gazebo Harmonic
# ROS 2 Humble Compatible, 2025
# --------------------------------------------------

#------------------------
# Cleanup on exit
#------------------------
function cleanup()
{
    echo "[INFO] Cleaning up PX4 and Gazebo processes..."
    pkill -x px4 || true
    pkill -x gz || true
}
trap "cleanup" SIGINT SIGTERM EXIT

#------------------------
# Spawning a model
#------------------------
function spawn_model()
{
    MODEL=$1
    N=$2
    X="${3:-0.0}"
    Y="${4:-$((N * 3))}"
    Z="0.83"

    SUPPORTED_MODELS=("x500_base" "rc_cessna" "r1_rover")
    if [[ ! " ${SUPPORTED_MODELS[*]} " =~ " ${MODEL} " ]]; then
        echo "[ERROR] Model $MODEL not supported!"
        exit 1
    fi

    working_dir="$build_path/rootfs/$n"
    mkdir -p "$working_dir"

    pushd "$working_dir" &>/dev/null
    echo "[INFO] Starting PX4 instance $N in $(pwd)..."
    $build_path/bin/px4 -i $N -d "$build_path/etc" >out.log 2>err.log &

    export MAVLINK_TCP_PORT=$((4560 + ${N}))
    export MAVLINK_UDP_PORT=$((14560 + ${N}))
    export MAVLINK_ID=$((1 + ${N}))
    export MAVLINK_CAM_UDP_PORT=$((14530 + ${N}))

    echo "[INFO] Spawning ${MODEL}_${N} at (${X}, ${Y})"
    gz service -s /world/${world}/create --reqtype gz.msgs.EntityFactory --reptype gz.msgs.Boolean --timeout 300 \
        --req "sdf_filename: \"$HOME/PX4-Autopilot/Tools/simulation/gz/models/${MODEL}/model.sdf\", name: \"${MODEL}_${N}\", pose: {position: {x: ${X}, y: ${Y}, z: ${Z}}}"

    echo "[INFO] Waiting for model ${MODEL}_${N} to appear in Gazebo..."
    timeout=30
    elapsed=0
    while ! gz model -m ${MODEL}_${N} --pose &> /dev/null; do
        sleep 1
        elapsed=$((elapsed + 1))
        if [ $elapsed -ge $timeout ]; then
            echo "[ERROR] Model ${MODEL}_${N} did not spawn within $timeout seconds!"
            exit 1
        fi
    done
    echo "[INFO] Model ${MODEL}_${N} successfully spawned."
    popd &>/dev/null
}

#------------------------
# Default Parameters
#------------------------

num_vehicles=${NUM_VEHICLES:=3}
world=${WORLD:=default}
target=${TARGET:=px4_sitl}
vehicle_model=${VEHICLE_MODEL:="x500_base"} 

pose_exists="false"
if [[ -n "${POSE_MAP}" ]]; then
    IFS='|' read -ra pose_map <<< "$POSE_MAP"
    pose_exists="true"
fi

export PX4_SIM_MODEL=${vehicle_model}

#------------------------
# Paths and Environment
#------------------------

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_path="$SCRIPT_DIR/../../.."

build_path=${src_path}/build/${target}

#export GZ_SIM_RESOURCE_PATH="$HOME/PX4-Autopilot/Tools/simulation/gz:
#$HOME/PX4-Autopilot/Tools/simulation/gz/models"
#export IGN_GAZEBO_RESOURCE_PATH=$GZ_SIM_RESOURCE_PATH

#echo "[INFO] GZ_SIM_RESOURCE_PATH and IGN_GAZEBO_RESOURCE_PATH set to: $GZ_SIM_RESOURCE_PATH"

#------------------------
# Clear Fuel Cache
#------------------------

if [ -d "$HOME/.gz/fuel" ]; then
    echo "[INFO] Clearing old Gazebo Fuel cache..."
    rm -rf "$HOME/.gz/fuel"
fi

#------------------------
# Launch Gazebo Harmonic
#------------------------

echo "[INFO] Starting Gazebo Harmonic with world: ${world}"
gz sim "$HOME/PX4-Autopilot/Tools/simulation/gz/worlds/${world}.sdf" --verbose --gui &
sleep 2

# Wait for Gazebo world services to be ready
echo "[INFO] Waiting for Gazebo world services to come online..."
until gz service -l | grep -q "/world/${world}/create"; do
    sleep 1
done
echo "[INFO] Gazebo is ready."

sleep 2

#------------------------
# Spawn Vehicles
#------------------------

n=0
if [ -z "${SCRIPT}" ]; then
    if [ $num_vehicles -gt 255 ]; then
        echo "[ERROR] Tried spawning $num_vehicles vehicles. Maximum is 255."
        exit 1
    fi

    while [ $n -lt $num_vehicles ]; do
        instance=$((n + 1))
        if [[ "${pose_exists}" == "true" ]]; then
            pose="${pose_map[$n]}"
            if [[ -n "$pose" ]]; then
                IFS=',' read -r x y <<< "$pose"
                spawn_model ${vehicle_model} ${instance} "${x}" "${y}"
            else
                spawn_model ${vehicle_model} ${instance}
            fi
        else
            spawn_model ${vehicle_model} ${instance}
        fi
        n=${instance}
    done
else
    IFS=,
    for target in ${SCRIPT}; do
        target="$(echo "$target" | tr -d ' ')" # Remove spaces
        target_vehicle=$(echo $target | cut -f1 -d:)
        target_number=$(echo $target | cut -f2 -d:)

        if [ $n -gt 255 ]; then
            echo "[ERROR] Tried spawning $n vehicles. Maximum is 255."
            exit 1
        fi

        m=0
        while [ $m -lt "${target_number}" ]; do
            export PX4_SIM_MODEL=${target_vehicle}
            instance=$((n + 1))
            if [[ "${pose_exists}" == "true" ]]; then
                pose="${pose_map[$n]}"
                if [[ -n "$pose" ]]; then
                    IFS=',' read -r x y <<< "$pose"
                    spawn_model "${target_vehicle}" ${instance} "${x}" "${y}"
                else
                    spawn_model "${target_vehicle}" ${instance}
                fi
            else
                spawn_model "${target_vehicle}" ${instance}
            fi
            n=${instance}
            m=$((m + 1))
        done
    done
fi
