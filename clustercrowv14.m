clc;
clear;
close all;

%% Parameters
numCrows = 5;           % Number of crows (cluster heads)
numIterations = 2000;   % Number of iterations
numNodes = 100;         % Number of sensor nodes
dim = 2;                % Dimension of the problem (2D space)
flightLength = 2;       % Maximum flight length (step size)
awarenessProb = 0.1;    % Probability of avoiding danger (awareness)

% Network Parameters
sinkNode = [50, 175];    % Sink node position
d0 = 87;                 % Reference distance for path loss
Eelec = 50e-9;           % Energy to run circuitry (J/bit)
Efs = 10e-12;            % FreeSpace model energy (J/bit/m^2)
Emp = 0.0013e-12;        % MultiPath model energy (J/bit/m^4)
dataPacketSize = 4000;   % Data packet size (bits)
initialEnergy = 0.5;     % Initial energy for each node (Joules)

%% Node Initialization
nodes(numNodes).position = [];
for i = 1:numNodes
    nodes(i).position = rand(1, 2) * 100;  % Random position in 100x100 grid
    nodes(i).energy = initialEnergy;       % Initial energy
    nodes(i).alive = true;                 % All nodes start alive
    nodes(i).clusterHead = false;          % No nodes are cluster heads initially
end

%% Initialization for CSA
crowsPosition = rand(numCrows, dim) * 100;  % Initial crow positions

memory = crowsPosition;                     % Memory for crow positions
fitness = inf(numCrows, 1);                 % Initial fitness values
totalEnergyHistory = zeros(numIterations, 1); % To record total energy usage
aliveNodesHistory = zeros(numIterations, 1); % To record number of alive nodes
previousCHs = [];

% Excel data storage
excelData = cell(numIterations, 4);  % Preallocate for efficiency

%% Visualization Initialization
figure;
hold on;
sinkPlot = plot(sinkNode(1), sinkNode(2), 'rs', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'DisplayName', 'Sink Node');  % Sink as red square
title('Node Locations and Sink');
xlabel('X Coordinate');
ylabel('Y Coordinate');
legend;
grid on;
xlim([0, 100]);
ylim([0, 200]);

%% Simulation
for iter = 1:numIterations
    % Reset cluster head status
    for i = 1:numNodes
        nodes(i).clusterHead = false;
    end
    
    % Form clusters based on previous crowsPosition
    clusters = formClusters(nodes, crowsPosition, numCrows,initialEnergy);

    % Calculate centroids for each cluster
    centroids = zeros(numCrows, dim);
    for j = 1:numCrows
        if ~isempty(clusters{j})
            centroids(j, :) = mean(vertcat(nodes(clusters{j}).position), 1);
        else
            centroids(j, :) = crowsPosition(j, :); % If no members, use crow position
        end
    end

    % Select cluster heads based on proximity to centroids and fitness
    availableNodes = find([nodes.alive]);
    candidateCHs = setdiff(availableNodes, previousCHs); % Avoid previously selected CHs

    selectedCH = [];
    for j = 1:numCrows
        if isempty(candidateCHs)
            candidateCHs = availableNodes; % Reset if no candidates available
        end

        if isempty(candidateCHs)
            break; % Break if no candidates available
        end

        % Calculate distances to centroid
        distances = sqrt(sum((vertcat(nodes(candidateCHs).position) - centroids(j, :)).^2, 2));

        % Consider fitness
        [~, sortedIdx] = sort(distances); % Sort by distance
        candidatesSorted = candidateCHs(sortedIdx);
        fitnessSorted = [nodes(candidatesSorted).energy]; % Higher energy = higher fitness

        [~, fitnessIdx] = max(fitnessSorted); % Select the one with highest fitness
        selectedCH = [selectedCH, candidatesSorted(fitnessIdx)];
        
        candidateCHs = setdiff(candidateCHs, selectedCH); % Remove selected CH from candidates
    end

    for i = selectedCH
        nodes(i).clusterHead = true;
    end

    previousCHs = selectedCH; % Store selected CHs to avoid repetition

    % Form clusters again with the new cluster heads
    if ~isempty(selectedCH)
        clusters = formClusters(nodes, vertcat(nodes(selectedCH).position), numCrows,initialEnergy);
    end

    % Prepare data for Excel sheet and CLI output
    clusterHeadNodes = find([nodes.clusterHead]);  % Find node numbers that are cluster heads
    numMembersPerCluster = cellfun(@length, clusters);  % Number of members in each cluster
    numAliveNodes = sum([nodes.alive]);  % Number of alive nodes
    remainingEnergy = sum([nodes.energy]);  % Total remaining energy

    % Handle empty cluster head nodes
    if isempty(clusterHeadNodes)
        clusterHeadNodesStr = 'None';
    else
        clusterHeadNodesStr = mat2str(clusterHeadNodes);
    end

    % Handle empty clusters
    if isempty(numMembersPerCluster)
        numMembersPerCluster = zeros(numCrows, 1);
    end

    % Save data for this iteration
    excelData{iter, 1} = iter;
    excelData{iter, 2} = clusterHeadNodesStr;
    excelData{iter, 3} = numAliveNodes;
    excelData{iter, 4} = remainingEnergy;

    % Display data in MATLAB CLI
    fprintf('Iteration: %d\n', iter);
    fprintf('Cluster Head Nodes: %s\n', clusterHeadNodesStr);
    fprintf('Number of Members per Cluster: %s\n', mat2str(numMembersPerCluster));
    fprintf('Number of Alive Nodes: %d\n', numAliveNodes);
    fprintf('Remaining Energy: %.4f J\n\n', remainingEnergy);

    % Clear previous plots for members and cluster heads
    delete(findobj(gca, 'Type', 'Line', 'Marker', 'o'));
    delete(findobj(gca, 'Type', 'Line', 'Marker', '*'));

    % Plot the cluster heads as stars and members as solid circles with unique colors
    colors = lines(numCrows); % Generate distinct colors
    for j = 1:numCrows
        if ~isempty(clusters{j})
            % Plot members
            memberPositions = vertcat(nodes(clusters{j}).position);
            plot(memberPositions(:, 1), memberPositions(:, 2), 'o', 'MarkerSize', 8, 'MarkerFaceColor', colors(j, :), 'MarkerEdgeColor', colors(j, :));
            % Plot cluster head
            plot(nodes(clusterHeadNodes(j)).position(1), nodes(clusterHeadNodes(j)).position(2), '*', 'MarkerSize', 12, 'MarkerFaceColor', colors(j, :), 'MarkerEdgeColor', colors(j, :));
        end
    end
    
    drawnow;

    % Early stopping if all nodes are dead
    if all(~[nodes.alive])
        disp('All nodes have depleted their energy. Simulation stopping early.');
        break;
    end

    % Update energy and fitness
    for crow = 1:numCrows
        % Crow's movement based on flight length and awareness probability
        if rand < awarenessProb
            newPosition = rand(1, dim) * 100;  % Random new position
        else
            randomCrow = randi(numCrows);
            newPosition = memory(randomCrow, :) + flightLength * (rand(1, dim) - 0.5) * 100 % Move towards another crow
        end
        newPosition = max(min(newPosition, 100), 0) % Boundary handling

        % Evaluate new position and update energy
        [newFitness, nodes] = objectiveFunction(newPosition, nodes, sinkNode, d0, Eelec, Efs, Emp, dataPacketSize, clusters, crow, crowsPosition);
       
        if newFitness < fitness(crow)
            crowsPosition(crow, :) = newPosition;  % Update crow position
            fitness(crow) = newFitness;            % Update fitness
            memory(crow, :) = newPosition;         % Update memory
        end
    end
    
    % Record data for plotting
    totalEnergyHistory(iter) = sum([nodes.energy]);
    aliveNodesHistory(iter) = sum([nodes.alive]);
    %pause(1)
end

%% Write data to Excel file
excelDataTable = cell2table(excelData, 'VariableNames', {'Iteration', 'ClusterHeadNodes', 'AliveNodes', 'RemainingEnergy'});
writetable(excelDataTable, 'CrowSearchAlgorithmResults.xlsx');

%% Plot results
figure;
plot(totalEnergyHistory, 'r-', 'LineWidth', 2);
title('Total Energy Consumption Over Iterations');
xlabel('Iteration');
ylabel('Total Energy (Joules)');
grid on;

figure;
plot(aliveNodesHistory, 'b-', 'LineWidth', 2);
title('Number of Alive Nodes Over Iterations');
xlabel('Iteration');
ylabel('Number of Alive Nodes');
grid on;

%% Display results
disp(['Simulation ended at iteration: ', num2str(iter)]);

%% Function Definitions

function clusters = formClusters(nodes, crowsPosition, numCrows,initialEnergy)
    clusters = cell(numCrows, 1);

    for i = 1:length(nodes)
        if nodes(i).alive
            distances = sqrt(sum((crowsPosition - nodes(i).position).^2, 2));%*initialEnergy/nodes(i).energy;
            [~, closestCrow] = min(distances);  % Find the closest crow (cluster head)
            clusters{closestCrow} = [clusters{closestCrow}, i];  % Assign node index to that cluster
        end
    end
end

function [totalEnergy, nodes] = objectiveFunction(crowPosition, nodes, sinkNode, d0, Eelec, Efs, Emp, packetSize, clusters, crowIdx, crowsPosition)
    totalEnergy = 0;

    if crowIdx > size(crowsPosition, 1)
        error('Crow index exceeds the size of crow positions');
    end

    for i = 1:length(clusters{crowIdx})
        nodeIdx = clusters{crowIdx}(i);
        if nodes(nodeIdx).alive
            if nodes(nodeIdx).clusterHead
                % Energy consumption for cluster head communicating with sink
                [energyConsumed, nodes(nodeIdx).energy] = calculateEnergy(nodes(nodeIdx).position, sinkNode, d0, Eelec, Efs, Emp, packetSize, nodes(nodeIdx).energy, true);
                
                
            else
                % Energy consumption for non-cluster head communicating with cluster head
                [energyConsumed, nodes(nodeIdx).energy] = calculateEnergy(nodes(nodeIdx).position, crowPosition, d0, Eelec, Efs, Emp, packetSize, nodes(nodeIdx).energy, false);
                
            end
            
            % Update total energy and check if node is dead
            totalEnergy = totalEnergy + energyConsumed;
            if nodes(nodeIdx).energy <= 0
                nodes(nodeIdx).alive = false;
            end
        end
             
            
    end
    
end

function [energy, newEnergy] = calculateEnergy(nodePos, targetPos, d0, Eelec, Efs, Emp, packetSize, currentEnergy, isClusterHead)
    distance = norm(nodePos - targetPos);
    
    if distance < d0
        energy = packetSize * Eelec + packetSize * Efs * distance^2;
    else
        energy = packetSize * Eelec + packetSize * Emp * distance^4;
    end
    
    if isClusterHead
        %energy = energy * 1.5;  % Cluster heads consume more energy
    end

    newEnergy = currentEnergy - energy;

    if newEnergy < 0
        newEnergy = 0;
    end
end
