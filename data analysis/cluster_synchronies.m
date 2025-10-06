function [IDX2, sCl, M, S, R, CellScore, CellScoreN, CellCl, NClOK, ...
          assemblyraw, assemblystat, RaceOK, clusterMatrix, validDirectory] = cluster_synchronies(directory, Race, kmean_iter, kmeans_surrogate)
    % -------------------------------------------------------------------------
    % cluster_synchronies
    % Effectue le clustering des synchronies (SCEs) et évalue leur signification.
    %
    % INPUTS :
    %   - directory : dossier de sauvegarde
    %   - Race : matrice binaire (cellules x SCEs)
    %   - kmean_iter : nombre d'itérations pour k-means
    %   - kmeans_surrogate : nombre de tirages aléatoires pour test de significativité
    %
    % OUTPUTS :
    %   - IDX2 : index des clusters pour chaque SCE
    %   - sCl : score de stabilité des clusters
    %   - M, S, R : matrices de k-means
    %   - CellScore / CellScoreN : scores absolus et normalisés par cluster
    %   - CellCl : cluster dominant par cellule
    %   - NClOK : nombre de clusters significatifs
    %   - assemblyraw : assemblées brutes
    %   - assemblystat : assemblées significatives
    %   - RaceOK : Race filtré pour clusters valides
    %   - clusterMatrix : [cellID, clusterID]
    %   - validDirectory : chemin du dossier si clustering réussi
    % -------------------------------------------------------------------------

    % === Initialisation par défaut (sécurité) ===
    IDX2 = [];
    sCl = [];
    M = [];
    S = [];
    R = {};
    CellScore = [];
    CellScoreN = [];
    CellCl = [];
    NClOK = 0;
    assemblyraw = {};
    assemblystat = {};
    RaceOK = [];
    clusterMatrix = [];
    validDirectory = '';

    try
        disp(['Processing folder: ', directory]);

        % Vérification Race
        if isempty(Race)
            warning('Race matrix is empty. Skipping folder: %s', directory);
            return;
        end

        [NCell, ~] = size(Race);

        % --- Étape 1 : K-means clustering principal ---
        [IDX2, sCl, M, S] = kmeansopttest(Race, kmean_iter, 'var');

        % --- Étape 2 : Tirages aléatoires pour seuil de significativité ---
        sClrnd = zeros(1, kmeans_surrogate);
        for i = 1:kmeans_surrogate
            sClrnd(i) = kmeansoptrnd(Race, 10, max(IDX2));
        end

        NCl = max(IDX2);
        NClOK = sum(sCl > prctile(sClrnd, 95));
        disp(['nClustersOK = ', num2str(NClOK)]);

        if NClOK < 1
            disp('No statistically significant clusters found.');
            return;
        end

        % --- Étape 3 : Scores de cellules par cluster ---
        R = cell(NCl, 1);
        CellScore = zeros(NCell, NCl);
        CellScoreN = zeros(NCell, NCl);

        for i = 1:NCl
            R{i} = find(IDX2 == i);
            CellScore(:, i) = sum(Race(:, R{i}), 2);
            CellScoreN(:, i) = CellScore(:, i) / length(R{i});
        end

        % --- Étape 4 : Attribution de cluster dominant ---
        [~, CellCl] = max(CellScoreN, [], 2);
        CellCl(max(CellScore, [], 2) < 2) = 0; % cellules trop peu actives

        % --- Assemblées brutes ---
        assemblyraw = cell(NCl, 1);
        for i = 1:NCl
            assemblyraw{i} = find(CellCl == i)';
        end

        % --- Assemblées significatives ---
        assemblystat = cell(NClOK, 1);
        for i = 1:NClOK
            assemblystat{i} = find(CellCl == i)';
        end

        % --- Étape 5 : Race filtré et matrice de clusters ---
        RaceOK = Race(:, IDX2 <= NClOK);
        NRaceOK = size(RaceOK, 2);
        disp(['nSCEOK = ', num2str(NRaceOK)]);

        % --- Construction de la clusterMatrix ---
        clusterId = zeros(NCell, 1);
        clusterMatrix = [];
        for cluster = 1:NClOK
            cellsInCluster = assemblystat{cluster};
            clusterId(cellsInCluster) = cluster;
            clusterMatrix = [clusterMatrix; cellsInCluster(:), clusterId(cellsInCluster)];
        end

        % --- Ajouter les cellules non clusterisées (0) ---
        all_cells = (1:NCell)';
        unclustered = setdiff(all_cells, clusterMatrix(:, 1));
        if ~isempty(unclustered)
            clusterMatrix = [clusterMatrix; unclustered(:), zeros(length(unclustered), 1)];
        end

        validDirectory = directory;

        % --- Étape 6 : Sauvegarde des résultats ---
        if NClOK > 0
            save(fullfile(directory, 'results_clustering.mat'), ...
                'IDX2', 'sCl', 'M', 'S', 'R', ...
                'CellScore', 'CellScoreN', 'CellCl', 'NClOK', ...
                'assemblyraw', 'assemblystat', 'RaceOK', ...
                'clusterMatrix', 'validDirectory');
            disp(['Saved: ', fullfile(directory, 'results_clustering.mat')]);
        else
            disp('No valid clusters, skipping save.');
        end

    catch ME
        disp(['Error processing folder: ', directory]);
        disp(['Message: ', ME.message]);
        for k = 1:numel(ME.stack)
            disp(['  at ', ME.stack(k).file, ' (line ', num2str(ME.stack(k).line), ')']);
        end
    end
end
