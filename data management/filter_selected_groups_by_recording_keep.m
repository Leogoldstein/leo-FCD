function [selected_groups, recap_filtered] = filter_selected_groups_by_recording_keep(selected_groups, recap_all)
%FILTER_SELECTED_GROUPS_BY_RECORDING_KEEP Ne garder que les recordings acceptes.
%
% [selected_groups, recap_filtered] = ...
%     filter_selected_groups_by_recording_keep(selected_groups, recap_all)
%
% La decision est prise PAR PLAN :
%   1  = accepte ; 0 = refuse ; [] = non decide.
% Une decision absente ou invalide declenche un warning non bloquant.
% Elle est traitee comme non acceptee, sans etre convertie en 0.
% Un recording reste selectionne si AU MOINS UN plan est accepte.
% Un animal sans recording accepte est retire.
%
% Si recap_all est fourni, la colonne recording_keep est utilisee avec
% une correspondance stricte Type + Line + Animal + Date + TSeries.
% Sinon, les statuts viennent de data.recording_keep_group{m}{p}.
%
% Les recordings ecartes sont retires de dates, ages, paths, metadata et
% data (en conservant les colonnes de chemins et les indices des plans).
% Les plans refuses/non decides d'un recording partiellement accepte ne
% sont PAS effaces : utiliser data.recording_keep_mask_group{m}(p) pour les
% ignorer dans les calculs par plan, sans decaler leurs indices physiques.
%
% Aucun fichier sur disque n'est modifie.

    if nargin < 1 || isempty(selected_groups)
        if nargin < 2
            recap_filtered = [];
        else
            recap_filtered = recap_all;
        end
        return;
    end

    use_recap = nargin >= 2 && ~isempty(recap_all);
    recap_filtered = [];

    if use_recap
        if ~istable(recap_all) || ...
                ~all(ismember( ...
                {'Type','Line','Animal','Date','TSeries','recording_keep'}, ...
                recap_all.Properties.VariableNames))
            error('filter_recordings:InvalidRecap', ...
                'recap_all doit contenir Type, Line, Animal, Date, TSeries et recording_keep.');
        end
        recap_rows_kept = false(height(recap_all),1);
        recap_types = string(recap_all.Type);
        recap_lines = string(recap_all.Line);
        recap_animals = string(recap_all.Animal);
        recap_dates = strings(height(recap_all),1);
        recap_tseries = strings(height(recap_all),1);
        for r = 1:height(recap_all)
            recap_dates(r) = normalize_date(recap_all.Date(r));
            recap_tseries(r) = tseries_name(recap_all.TSeries(r));
        end
    end

    type_names = fieldnames(selected_groups);
    for t = 1:numel(type_names)
        type_name = type_names{t};
        animals = selected_groups.(type_name);
        filtered_animals = animals([]);

        for k = 1:numel(animals)
            group = animals(k);
            nRec = recording_count(group);
            if nRec == 0
                continue;
            end

            if ~isfield(group,'data') || ~isstruct(group.data)
                group.data = struct();
            end

            keep_recordings = false(nRec,1);
            plane_masks = cell(nRec,1);
            statuses = cell(nRec,1);

            for m = 1:nRec
                if use_recap
                    if ~isfield(group,'dates') || numel(group.dates) < m || ...
                            ~isfield(group,'paths') || ...
                            ~isfield(group.paths,'TSeries') || ...
                            size(group.paths.TSeries,1) < m
                        error('filter_recordings:MissingIdentity', ...
                            'Date ou TSeries absent : %s / %s, recording %d.', ...
                            type_name, string(group.animal), m);
                    end

                    current_date = normalize_date(record_item(group.dates,m));
                    current_tseries = tseries_name(group.paths.TSeries{m,1});
                    match = strcmpi(recap_types,string(type_name)) & ...
                            strcmpi(recap_lines,string(group.line)) & ...
                            strcmpi(recap_animals,string(group.animal)) & ...
                            strcmpi(recap_dates,current_date) & ...
                            strcmpi(recap_tseries,current_tseries);
                    idx = find(match);
                    if numel(idx) ~= 1
                        error('filter_recordings:RecapMatch', ...
                            ['Correspondance recap non unique ou absente : ' ...
                             '%s / %s / %s / %s / %s (%d ligne(s)).'], ...
                            type_name, string(group.line), string(group.animal), ...
                            current_date, current_tseries, numel(idx));
                    end
                    raw = recap_all.recording_keep{idx};
                else
                    if isfield(group.data,'recording_keep_group') && ...
                            iscell(group.data.recording_keep_group) && ...
                            numel(group.data.recording_keep_group) >= m
                        raw = group.data.recording_keep_group{m};
                    else
                        raw = [];
                    end
                end

                warn_missing_decisions(raw, type_name, group, m);
                statuses{m} = raw;
                plane_masks{m} = accepted_planes(raw);
                keep_recordings(m) = any(plane_masks{m});
                if use_recap && keep_recordings(m)
                    recap_rows_kept(idx) = true;
                end
            end

            keep_idx = find(keep_recordings);
            fprintf('%s / %s : %d recording(s) conserve(s) sur %d.\n', ...
                type_name, char(string(group.animal)), numel(keep_idx), nRec);
            if isempty(keep_idx)
                continue;
            end

            % Sous-ensemble recursif : cellules {m}, chemins (m,:), et
            % sous-structures de metadata / data restent synchronises.
            group = subset_recording_fields(group, keep_idx, nRec);
            group.data.recording_keep_mask_group = plane_masks(keep_idx);
            if use_recap
                group.data.recording_keep_group = statuses(keep_idx);
            end
            filtered_animals(end+1) = group; %#ok<AGROW>
        end

        selected_groups.(type_name) = filtered_animals;
    end

    if use_recap
        recap_filtered = recap_all(recap_rows_kept,:);
    end
end

% ================================================================
function warn_missing_decisions(raw, type_name, group, m)
    % Le warning n'interrompt jamais le filtrage. Les plans sans decision
    % ne sont pas acceptes mais restent distincts d'un rejet explicite (0).
    record_label = sprintf('%s / %s / recording %d', ...
        char(string(type_name)), char(string(group.animal)), m);

    if isfield(group,'dates') && numel(group.dates) >= m
        record_label = sprintf('%s / %s', record_label, ...
            char(normalize_date(record_item(group.dates,m))));
    end
    if isfield(group,'paths') && isstruct(group.paths) && ...
            isfield(group.paths,'TSeries') && ...
            size(group.paths.TSeries,1) >= m
        record_label = sprintf('%s / %s', record_label, ...
            char(tseries_name(group.paths.TSeries{m,1})));
    end

    if iscell(raw)
        if isempty(raw)
            warning('filter_recordings:DecisionMissing', ...
                'Decision recording_keep absente : %s. Recording non retenu sauf autre plan accepte.', ...
                record_label);
            return;
        end

        for p = 1:numel(raw)
            if ~is_valid_decision(raw{p})
                warning('filter_recordings:DecisionMissing', ...
                    'Decision recording_keep absente ou invalide : %s / plan %d. Plan non retenu.', ...
                    record_label, p-1);
            end
        end
    elseif ~is_valid_decision(raw)
        warning('filter_recordings:DecisionMissing', ...
            'Decision recording_keep absente ou invalide : %s. Recording non retenu sauf autre plan accepte.', ...
            record_label);
    end
end

function tf = is_valid_decision(value)
    tf = (isnumeric(value) || islogical(value)) && ...
         isscalar(value) && isreal(value) && ...
         isfinite(double(value)) && ismember(double(value),[0 1]);
end

% ================================================================
function n = recording_count(group)
    n = 0;
    if isfield(group,'paths') && isstruct(group.paths) && ...
            isfield(group.paths,'TSeries') && ~isempty(group.paths.TSeries)
        n = size(group.paths.TSeries,1); % 1 x N colonnes = 1 recording.
    elseif isfield(group,'dates') && ~isempty(group.dates)
        n = numel(group.dates);
    elseif isfield(group,'data') && isstruct(group.data) && ...
            isfield(group.data,'recording_keep_group')
        n = numel(group.data.recording_keep_group);
    end
end

% ================================================================
function mask = accepted_planes(raw)
    if iscell(raw)
        mask = false(numel(raw),1);
        for p = 1:numel(raw)
            mask(p) = is_accepted(raw{p});
        end
    else
        % Ancien format : decision commune a tous les plans.
        mask = is_accepted(raw);
    end
end

function tf = is_accepted(value)
    tf = (isnumeric(value) || islogical(value)) && ...
         isscalar(value) && isreal(value) && ...
         isfinite(double(value)) && double(value) == 1;
end

% ================================================================
function out = subset_recording_fields(value, idx, nRec)
    % Les structures scalaires sont des conteneurs : explorer leurs champs.
    % Les tableaux de structures a nRec elements sont indexes directement.
    if isstruct(value)
        if isscalar(value)
            out = value;
            fn = fieldnames(value);
            for f = 1:numel(fn)
                out.(fn{f}) = subset_recording_fields(value.(fn{f}), idx, nRec);
            end
        elseif numel(value) == nRec
            out = value(idx);
        else
            out = value;
        end
    elseif iscell(value)
        if size(value,1) == nRec
            out = value(idx,:); % Garde les colonnes TSeries/suite2p.
        elseif isvector(value) && numel(value) == nRec
            out = value(idx);
        else
            out = value; % Champs globaux / tableau des plans.
        end
    elseif (isnumeric(value) || islogical(value) || isstring(value)) && ...
            isvector(value) && numel(value) == nRec && nRec > 1
        out = value(idx);
    elseif istable(value) && height(value) == nRec
        out = value(idx,:);
    else
        out = value; % Identifiants animal, texte, matrices, etc.
    end
end

% ================================================================
function value = record_item(items,m)
    if iscell(items)
        value = items{m};
    else
        value = items(m);
    end
end

function date_text = normalize_date(value)
    while iscell(value)
        if isempty(value), date_text = ""; return; end
        value = value{1};
    end
    if isdatetime(value)
        date_text = string(value,'dd-MM-yyyy');
    else
        date_text = string(value);
    end
    if isempty(date_text) || ismissing(date_text(1))
        date_text = "";
    else
        date_text = strtrim(date_text(1));
    end
end

function name = tseries_name(value)
    while iscell(value)
        if isempty(value), name = ""; return; end
        value = value{1};
    end
    if isempty(value)
        name = "";
        return;
    end
    path = regexprep(char(string(value)),'[\\/]+$','');
    chunks = regexp(path,'[\\/]','split');
    name = string(chunks{end});
end
