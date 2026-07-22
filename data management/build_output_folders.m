function output_folders = build_output_folders( ...
        selected_groups, ...
        root_folders, ...
        automatic_selection, ...
        include_blue_cells)
%BUILD_OUTPUT_FOLDERS
%
% Construit un dossier de sortie pour chaque type contenu dans
% selected_groups.
%
% Entrées :
%   selected_groups
%       Structure dont chaque champ correspond à un type d'animal.
%
%   root_folders
%       Dossier racine de chaque type.
%
%       Formats acceptés :
%           - char
%           - string scalaire
%           - string array
%           - cellule de char/string
%
%       Si un seul dossier est fourni pour plusieurs types, il est
%       appliqué à tous les types.
%
%   automatic_selection
%       Indique si la sélection est automatique pour chaque type.
%
%       Formats acceptés :
%           - logical scalaire
%           - numérique scalaire
%           - vecteur logical
%           - vecteur numérique
%           - cellule contenant des valeurs logiques ou numériques
%
%       Si une seule valeur est fournie pour plusieurs types, elle est
%       appliquée à tous les types.
%
%   include_blue_cells
%       Indique si les cellules électroporées sont incluses.
%
%       Doit pouvoir être converti en scalaire logique.
%
% Sortie :
%   output_folders
%       Cellule n_types x 1 contenant un dossier par type, dans le même
%       ordre que fieldnames(selected_groups).
%
% Arborescence produite :
%
%   root_folder/
%   └── Summary plots/
%       ├── Pre-selection GCaMP only/
%       ├── Pre-selection electroporated cells/
%       ├── Manual selection GCaMP only/
%       └── Manual selection electroporated cells/
%
% Exemple :
%
%   output_folders = build_output_folders( ...
%       selected_groups, ...
%       {'D:\Imaging\WT'; 'D:\Imaging\FCD'}, ...
%       [true; false], ...
%       true);

    %==============================================================%
    % Vérification de selected_groups
    %==============================================================%
    if nargin < 1 || isempty(selected_groups)

        fprintf('Output folders: selected_groups vide.\n');

        output_folders = {};
        return;
    end

    if ~isstruct(selected_groups)

        error( ...
            'build_output_folders:InvalidSelectedGroups', ...
            'selected_groups doit être une structure.');
    end

    type_names = fieldnames(selected_groups);
    n_types = numel(type_names);

    if n_types == 0

        fprintf('Output folders: aucun type trouvé.\n');

        output_folders = {};
        return;
    end

    %==============================================================%
    % Valeurs par défaut
    %==============================================================%
    if nargin < 2 || isempty(root_folders)
        root_folders = repmat({pwd}, n_types, 1);
    end

    if nargin < 3 || isempty(automatic_selection)
        automatic_selection = false(n_types, 1);
    end

    if nargin < 4 || isempty(include_blue_cells)
        include_blue_cells = false;
    end

    %==============================================================%
    % Normalisation des entrées
    %==============================================================%
    root_folders = normalize_root_folders_DF( ...
        root_folders, ...
        n_types);

    automatic_selection = normalize_automatic_selection_DF( ...
        automatic_selection, ...
        n_types);

    include_blue_cells = parse_logical_scalar_DF( ...
        include_blue_cells, ...
        false);

    %==============================================================%
    % Construction des dossiers
    %==============================================================%
    output_folders = cell(n_types, 1);

    for t = 1:n_types

        current_root_folder = root_folders{t};
        current_automatic_selection = automatic_selection(t);

        summary_root_folder = fullfile( ...
            current_root_folder, ...
            'Summary plots');

        summary_subfolder = get_summary_subfolder_DF( ...
            current_automatic_selection, ...
            include_blue_cells);

        output_folders{t} = fullfile( ...
            summary_root_folder, ...
            summary_subfolder);
    end
end


%==========================================================================%
% HELPER : normaliser les dossiers racines
%==========================================================================%
function root_folders = normalize_root_folders_DF( ...
        root_folders, ...
        n_types)
%NORMALIZE_ROOT_FOLDERS_DF
%
% Convertit root_folders en cellule colonne de char, avec exactement
% n_types entrées.

    if nargin < 2 || isempty(n_types) || n_types < 1

        root_folders = {};
        return;
    end

    %----------------------------------------------------------------------%
    % Conversion vers une cellule
    %----------------------------------------------------------------------%
    if ischar(root_folders)

        root_folders = {root_folders};

    elseif isstring(root_folders)

        root_folders = cellstr(root_folders(:));

    elseif iscell(root_folders)

        root_folders = root_folders(:);

    else

        error( ...
            'build_output_folders:InvalidRootFolders', ...
            ['root_folders doit être un char, un string, ', ...
             'un string array ou une cellule.']);
    end

    %----------------------------------------------------------------------%
    % Validation du contenu de chaque cellule
    %----------------------------------------------------------------------%
    for i = 1:numel(root_folders)

        current_folder = root_folders{i};

        if isstring(current_folder)

            if ~isscalar(current_folder)

                error( ...
                    'build_output_folders:InvalidRootFolderString', ...
                    ['Chaque élément de root_folders doit contenir ', ...
                     'un seul chemin.']);
            end

            current_folder = char(current_folder);
        end

        if ~ischar(current_folder)

            error( ...
                'build_output_folders:InvalidRootFolderElement', ...
                ['Chaque élément de root_folders doit être un char ', ...
                 'ou un string scalaire.']);
        end

        current_folder = strtrim(current_folder);

        if isempty(current_folder)
            current_folder = pwd;
        end

        root_folders{i} = current_folder;
    end

    %----------------------------------------------------------------------%
    % Adaptation au nombre de types
    %----------------------------------------------------------------------%
    if isempty(root_folders)

        root_folders = repmat({pwd}, n_types, 1);

    elseif numel(root_folders) == 1 && n_types > 1

        root_folders = repmat(root_folders, n_types, 1);

    elseif numel(root_folders) ~= n_types

        error( ...
            'build_output_folders:RootFolderCountMismatch', ...
            ['Le nombre de dossiers racines (%d) doit être égal ', ...
             'au nombre de types (%d), ou être égal à 1.'], ...
            numel(root_folders), ...
            n_types);
    end
end


%==========================================================================%
% HELPER : normaliser automatic_selection
%==========================================================================%
function automatic_selection = normalize_automatic_selection_DF( ...
        automatic_selection, ...
        n_types)
%NORMALIZE_AUTOMATIC_SELECTION_DF
%
% Convertit automatic_selection en vecteur logique colonne contenant
% exactement n_types valeurs.

    if nargin < 2 || isempty(n_types) || n_types < 1

        automatic_selection = false(0, 1);
        return;
    end

    if isempty(automatic_selection)

        automatic_selection = false(n_types, 1);
        return;
    end

    %----------------------------------------------------------------------%
    % Cellule
    %----------------------------------------------------------------------%
    if iscell(automatic_selection)

        parsed_values = false(numel(automatic_selection), 1);

        for i = 1:numel(automatic_selection)

            parsed_values(i) = parse_logical_scalar_DF( ...
                automatic_selection{i}, ...
                false);
        end

        automatic_selection = parsed_values;

    %----------------------------------------------------------------------%
    % Tableau string
    %----------------------------------------------------------------------%
    elseif isstring(automatic_selection)

        parsed_values = false(numel(automatic_selection), 1);

        for i = 1:numel(automatic_selection)

            parsed_values(i) = parse_logical_scalar_DF( ...
                automatic_selection(i), ...
                false);
        end

        automatic_selection = parsed_values;

    %----------------------------------------------------------------------%
    % Char unique
    %----------------------------------------------------------------------%
    elseif ischar(automatic_selection)

        automatic_selection = parse_logical_scalar_DF( ...
            automatic_selection, ...
            false);

    %----------------------------------------------------------------------%
    % Logique ou numérique
    %----------------------------------------------------------------------%
    elseif islogical(automatic_selection) || ...
            isnumeric(automatic_selection)

        automatic_selection = automatic_selection(:) ~= 0;

    else

        error( ...
            'build_output_folders:InvalidAutomaticSelection', ...
            ['automatic_selection doit être logique, numérique, ', ...
             'string, char ou cellule.']);
    end

    automatic_selection = logical(automatic_selection(:));

    %----------------------------------------------------------------------%
    % Adaptation au nombre de types
    %----------------------------------------------------------------------%
    if numel(automatic_selection) == 1 && n_types > 1

        automatic_selection = repmat( ...
            automatic_selection, ...
            n_types, ...
            1);

    elseif numel(automatic_selection) ~= n_types

        error( ...
            'build_output_folders:AutomaticSelectionCountMismatch', ...
            ['Le nombre de valeurs automatic_selection (%d) doit ', ...
             'être égal au nombre de types (%d), ou être égal à 1.'], ...
            numel(automatic_selection), ...
            n_types);
    end
end


%==========================================================================%
% HELPER : convertir une valeur en logique scalaire
%==========================================================================%
function logical_value = parse_logical_scalar_DF( ...
        input_value, ...
        default_value)
%PARSE_LOGICAL_SCALAR_DF
%
% Convertit différentes représentations en une valeur logique scalaire.
%
% Valeurs textuelles vraies acceptées :
%   true, yes, oui, on, 1
%
% Valeurs textuelles fausses acceptées :
%   false, no, non, off, 0

    if nargin < 2 || isempty(default_value)
        default_value = false;
    end

    default_value = logical(default_value(1));

    if isempty(input_value)

        logical_value = default_value;
        return;
    end

    %----------------------------------------------------------------------%
    % Cellule scalaire
    %----------------------------------------------------------------------%
    if iscell(input_value)

        if numel(input_value) ~= 1

            error( ...
                'build_output_folders:NonScalarLogicalCell', ...
                'La cellule à convertir doit contenir une seule valeur.');
        end

        logical_value = parse_logical_scalar_DF( ...
            input_value{1}, ...
            default_value);

        return;
    end

    %----------------------------------------------------------------------%
    % Logique
    %----------------------------------------------------------------------%
    if islogical(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarLogical', ...
                'La valeur logique doit être scalaire.');
        end

        logical_value = input_value;
        return;
    end

    %----------------------------------------------------------------------%
    % Numérique
    %----------------------------------------------------------------------%
    if isnumeric(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarNumericLogical', ...
                'La valeur numérique à convertir doit être scalaire.');
        end

        if ~isfinite(input_value)

            logical_value = default_value;
            return;
        end

        logical_value = input_value ~= 0;
        return;
    end

    %----------------------------------------------------------------------%
    % String
    %----------------------------------------------------------------------%
    if isstring(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarStringLogical', ...
                'Le string à convertir doit être scalaire.');
        end

        input_value = char(input_value);
    end

    %----------------------------------------------------------------------%
    % Texte
    %----------------------------------------------------------------------%
    if ischar(input_value)

        normalized_value = lower(strtrim(input_value));

        true_values = { ...
            'true', ...
            'yes', ...
            'oui', ...
            'on', ...
            '1'};

        false_values = { ...
            'false', ...
            'no', ...
            'non', ...
            'off', ...
            '0'};

        if any(strcmp(normalized_value, true_values))

            logical_value = true;
            return;
        end

        if any(strcmp(normalized_value, false_values))

            logical_value = false;
            return;
        end

        warning( ...
            'build_output_folders:UnknownLogicalText', ...
            ['Valeur logique textuelle non reconnue : "%s". ', ...
             'La valeur par défaut est utilisée.'], ...
            input_value);

        logical_value = default_value;
        return;
    end

    warning( ...
        'build_output_folders:UnsupportedLogicalType', ...
        ['Type non pris en charge pour la conversion logique. ', ...
         'La valeur par défaut est utilisée.']);

    logical_value = default_value;
end


%==========================================================================%
% HELPER : sélectionner le nom du sous-dossier
%==========================================================================%
function summary_subfolder = get_summary_subfolder_DF( ...
        automatic_selection, ...
        include_blue_cells)
%GET_SUMMARY_SUBFOLDER_DF
%
% Retourne le nom du sous-dossier correspondant au mode de sélection
% et au type de cellules incluses.

    automatic_selection = parse_logical_scalar_DF( ...
        automatic_selection, ...
        false);

    include_blue_cells = parse_logical_scalar_DF( ...
        include_blue_cells, ...
        false);

    if automatic_selection && include_blue_cells

        summary_subfolder = ...
            'Pre-selection electroporated cells';

    elseif automatic_selection && ~include_blue_cells

        summary_subfolder = ...
            'Pre-selection GCaMP only';

    elseif ~automatic_selection && include_blue_cells

        summary_subfolder = ...
            'Manual selection electroporated cells';

    else

        summary_subfolder = ...
            'Manual selection GCaMP only';
    end
end