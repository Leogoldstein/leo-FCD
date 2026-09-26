function [output_folders_type, output_folders_line, output_folders_animal] = ...
        build_visualization_output_folders(selected_groups, type_names)
%BUILD_VISUALIZATION_OUTPUT_FOLDERS Dossiers de figures type/lignee/animal.
%
% Chemin source :
%   ...\Summary plots\<mode>\Development|Adult\line\animal\date\TSeries\...
%   (un separateur final est accepte).
%
% Sorties :
%   output_folders_type{t}        = ...\Adult
%   output_folders_line{t}{l}     = ...\Adult\mtor46
%   output_folders_animal{t}{l}{a} = ...\Adult\mtor46\2469
%
% t : ordre de type_names.
% l : ordre unique(...,'stable') des .line de ce type.
% a : ordre unique(...,'stable') des .animal de cette lignee.
% Les sorties s'arretent exactement aux niveaux indiques : jamais date/TSeries.
% Les anciens appels demandant deux sorties restent compatibles.

    if ~isstruct(selected_groups)
        error('selected_groups doit etre une structure.');
    end
    if nargin < 2 || isempty(type_names)
        type_names = fieldnames(selected_groups);
    end
    if isstring(type_names) || ischar(type_names)
        type_names = cellstr(type_names);
    end

    nTypes = numel(type_names);
    output_folders_type = cell(nTypes,1);
    output_folders_line = cell(nTypes,1);
    output_folders_animal = cell(nTypes,1);

    for t = 1:nTypes
        current_type = char(string(type_names{t}));
        output_folders_type{t} = '';
        output_folders_line{t} = {};
        output_folders_animal{t} = {};

        if ~isfield(selected_groups,current_type)
            warning('Type absent de selected_groups : %s.',current_type);
            continue;
        end
        groups = selected_groups.(current_type);
        if isempty(groups), continue; end

        line_values = strings(numel(groups),1);
        animal_values = strings(numel(groups),1);
        for k = 1:numel(groups)
            if isfield(groups(k),'line') && ~isempty(groups(k).line)
                line_values(k) = string(groups(k).line);
            end
            if isfield(groups(k),'animal') && ~isempty(groups(k).animal)
                animal_values(k) = string(groups(k).animal);
            end
        end
        unique_lines = unique(line_values,'stable');
        unique_lines(strlength(unique_lines)==0) = [];
        output_folders_line{t} = cell(numel(unique_lines),1);
        output_folders_animal{t} = cell(numel(unique_lines),1);

        for l = 1:numel(unique_lines)
            line_name = char(unique_lines(l));
            member_idx = find(line_values == unique_lines(l));
            line_folder = '';

            % Identifier le vrai dossier de lignee dans les chemins sources.
            for k = member_idx(:)'
                paths = get_group_output_paths(groups(k));
                for m = 1:numel(paths)
                    line_folder = find_line_folder(paths{m},line_name);
                    if ~isempty(line_folder), break; end
                end
                if ~isempty(line_folder), break; end
            end

            if isempty(line_folder)
                warning('Aucun dossier de lignee "%s" trouve pour %s.', ...
                    line_name,current_type);
                output_folders_line{t}{l} = '';
                output_folders_animal{t}{l} = {};
                continue;
            end

            output_folders_line{t}{l} = line_folder;
            type_folder = fileparts(line_folder);
            if isempty(output_folders_type{t})
                output_folders_type{t} = type_folder;
            elseif ~strcmpi(output_folders_type{t},type_folder)
                warning('Dossiers parents differents pour %s : "%s" / "%s".', ...
                    current_type,output_folders_type{t},type_folder);
            end
            if exist(type_folder,'dir') ~= 7, mkdir(type_folder); end
            if exist(line_folder,'dir') ~= 7, mkdir(line_folder); end

            % Animaux uniques de CETTE lignee, dans leur ordre d'apparition.
            animals_in_line = animal_values(member_idx);
            animals_in_line = unique(animals_in_line,'stable');
            animals_in_line(strlength(animals_in_line)==0) = [];
            output_folders_animal{t}{l} = cell(numel(animals_in_line),1);

            for a = 1:numel(animals_in_line)
                animal_name = char(animals_in_line(a));
                animal_folder = '';
                animal_idx = member_idx(animal_values(member_idx)==animals_in_line(a));
                for k = animal_idx(:)'
                    paths = get_group_output_paths(groups(k));
                    for m = 1:numel(paths)
                        candidate = find_animal_folder(paths{m},line_folder,animal_name);
                        if ~isempty(candidate)
                            animal_folder = candidate;
                            break;
                        end
                    end
                    if ~isempty(animal_folder), break; end
                end

                if isempty(animal_folder)
                    warning('Dossier animal introuvable : %s | %s | %s.', ...
                        current_type,line_name,animal_name);
                    output_folders_animal{t}{l}{a} = '';
                    continue;
                end
                output_folders_animal{t}{l}{a} = animal_folder;
                if exist(animal_folder,'dir') ~= 7, mkdir(animal_folder); end
            end
        end
    end
end


%==========================================================================
% Extraire les chemins de sortie d'un groupe, sans inventer de dossier.
%==========================================================================
function paths = get_group_output_paths(group)
    paths = {};
    if ~isfield(group,'paths') || ~isstruct(group.paths) || ...
            ~isfield(group.paths,'output_folders') || ...
            isempty(group.paths.output_folders)
        return;
    end
    raw = group.paths.output_folders;
    if ~iscell(raw), raw = {raw}; end
    for i = 1:numel(raw)
        if (ischar(raw{i}) || (isstring(raw{i}) && isscalar(raw{i}))) && ...
                ~isempty(raw{i})
            paths{end+1,1} = raw{i}; %#ok<AGROW>
        end
    end
end


%==========================================================================
% Rechercher un ancetre correspondant exactement a la lignee.
%==========================================================================
function line_folder = find_line_folder(input_path,line_name)
    line_folder = '';
    path = normalize_input_path(input_path);
    while ~isempty(path)
        [parent,folder_name] = fileparts(path);
        if strcmpi(folder_name,line_name)
            line_folder = path;
            return;
        end
        if isempty(parent) || strcmp(parent,path), return; end
        path = normalize_input_path(parent);
    end
end


%==========================================================================
% Identifier animal UNIQUEMENT s'il est immediatement sous cette lignee.
% Ainsi, date et TSeries ne peuvent jamais etre confondus avec un animal.
%==========================================================================
function animal_folder = find_animal_folder(input_path,line_folder,animal_name)
    animal_folder = '';
    path = normalize_input_path(input_path);
    line_folder = normalize_input_path(line_folder);
    while ~isempty(path)
        [parent,folder_name] = fileparts(path);
        if strcmpi(folder_name,animal_name) && strcmpi( ...
                normalize_input_path(parent),line_folder)
            animal_folder = path;
            return;
        end
        if isempty(parent) || strcmp(parent,path), return; end
        path = normalize_input_path(parent);
    end
end


function path = normalize_input_path(input_path)
    path = '';
    if ~(ischar(input_path) || (isstring(input_path) && isscalar(input_path)))
        return;
    end
    path = strtrim(char(string(input_path)));
    if isempty(path), return; end
    % Ne pas retirer le separateur des racines (C:\ ou /).
    if ~isempty(regexp(path,'^[A-Za-z]:[\\/]$','once')) || ...
            strcmp(path,'/') || strcmp(path,'\')
        return;
    end
    path = regexprep(path,'[\\/]+$','');
end
