function [FPaths, statPaths, iscellPaths, opsPaths, spksPaths, truedataFolders] = ...
    preprocess_npy_files(dataFolders_by_group)

% PREPROCESS_NPY_FILES
%
% Recherche directement les fichiers Suite2p dans les dossiers fournis.
%
% ENTRÉE
%   dataFolders_by_group :
%       cellule contenant les dossiers de données.
%
%       Exemple :
%       {
%           'D:\Imaging\jm\jm031\2023-10-18\'
%           'D:\Imaging\jm\jm032\2023-10-19\'
%       }
%
% SORTIES
%   FPaths          : chemins vers F.npy
%   statPaths       : chemins vers stat.npy
%   iscellPaths     : chemins vers iscell.npy
%   opsPaths        : chemins vers ops.npy
%   spksPaths       : chemins vers spks.npy
%   truedataFolders : dossiers contenant les fichiers Suite2p
%
% Aucun fichier n'est copié ou déplacé.

    % ============================================================
    % Vérification entrée
    % ============================================================
    if nargin < 1 || isempty(dataFolders_by_group)

        FPaths = {};
        statPaths = {};
        iscellPaths = {};
        opsPaths = {};
        spksPaths = {};
        truedataFolders = {};

        return;
    end

    % Accepter également un chemin unique fourni comme char/string
    if ischar(dataFolders_by_group) || isstring(dataFolders_by_group)
        dataFolders_by_group = cellstr(dataFolders_by_group);
    end

    % Format colonne
    dataFolders_by_group = dataFolders_by_group(:);

    % Enlever les entrées vides
    empty_mask = cellfun( ...
        @(x) isempty(x) || strlength(string(x)) == 0, ...
        dataFolders_by_group);

    dataFolders_by_group(empty_mask) = [];

    % ============================================================
    % Initialisation
    % ============================================================
    nFolders = numel(dataFolders_by_group);

    FPaths = cell(nFolders, 1);
    statPaths = cell(nFolders, 1);
    iscellPaths = cell(nFolders, 1);
    opsPaths = cell(nFolders, 1);
    spksPaths = cell(nFolders, 1);

    valid_folder = false(nFolders, 1);

    % ============================================================
    % Parcours des dossiers
    % ============================================================
    for k = 1:nFolders

        current_folder = char(dataFolders_by_group{k});

        fprintf('\nProcessing folder %d / %d:\n%s\n', ...
            k, nFolders, current_folder);

        % --------------------------------------------------------
        % Vérifier que le dossier existe
        % --------------------------------------------------------
        if ~exist(current_folder, 'dir')

            warning( ...
                'Folder does not exist: %s', ...
                current_folder);

            continue;
        end

        % --------------------------------------------------------
        % Chemins attendus
        % --------------------------------------------------------
        current_F = fullfile(current_folder, 'F.npy');
        current_stat = fullfile(current_folder, 'stat.npy');
        current_iscell = fullfile(current_folder, 'iscell.npy');
        current_ops = fullfile(current_folder, 'ops.npy');
        current_spks = fullfile(current_folder, 'spks.npy');

        % --------------------------------------------------------
        % Vérifier chaque fichier
        % --------------------------------------------------------
        if exist(current_F, 'file')
            FPaths{k} = current_F;
        else
            warning('F.npy not found in: %s', current_folder);
        end

        if exist(current_stat, 'file')
            statPaths{k} = current_stat;
        else
            warning('stat.npy not found in: %s', current_folder);
        end

        if exist(current_iscell, 'file')
            iscellPaths{k} = current_iscell;
        else
            warning('iscell.npy not found in: %s', current_folder);
        end

        if exist(current_ops, 'file')
            opsPaths{k} = current_ops;
        else
            warning('ops.npy not found in: %s', current_folder);
        end

        if exist(current_spks, 'file')
            spksPaths{k} = current_spks;
        else
            warning('spks.npy not found in: %s', current_folder);
        end

        % --------------------------------------------------------
        % Le dossier est conservé s'il contient au moins un
        % des fichiers Suite2p recherchés
        % --------------------------------------------------------
        valid_folder(k) = ...
            ~isempty(FPaths{k}) || ...
            ~isempty(statPaths{k}) || ...
            ~isempty(iscellPaths{k}) || ...
            ~isempty(opsPaths{k}) || ...
            ~isempty(spksPaths{k});
    end

    % ============================================================
    % Dossiers réellement utilisés
    % ============================================================
    truedataFolders = dataFolders_by_group(valid_folder);

    % ============================================================
    % Résumé
    % ============================================================
    fprintf('\n========================================\n');
    fprintf('Suite2p folders found: %d / %d\n', ...
        nnz(valid_folder), nFolders);
    fprintf('========================================\n');

    for k = 1:numel(truedataFolders)
        fprintf('%s\n', truedataFolders{k});
    end
end