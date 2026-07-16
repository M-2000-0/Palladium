#!/bin/bash
docker_running() {
    docker info &>/dev/null 2>&1
}

docker_start_daemon() {
    if ! docker_running; then
        echo -e "${YELLOW}Starting Docker...${NC}"
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        local i=0
        while ! docker_running && [ $i -lt 10 ]; do sleep 1; ((i++)); done
    fi
}
