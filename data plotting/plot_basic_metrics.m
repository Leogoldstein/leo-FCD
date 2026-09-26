function figs = plot_basic_metrics( ...
        selected_groups, ...
        include_electroporated, ...
        output_folders_type, ...
        output_folders_line, ...
        output_folders_animal, ...
        legend_table, ...
        pooled_level)
%PLOT_BASIC_METRICS_BY_LINE Figures de metriques GCaMP par type, lignee et animal.
%
% IMPORTANT :
% - Les cellules electroporees / blue sont ignorees dans cette fonction.
% - include_electroporated est conserve uniquement pour compatibilite.
%
% ENTREES :
%   output_folders_type{t}             -> dossier racine du type
%   output_folders_line{t}{l}          -> dossier racine de la lignee
%   output_folders_animal{t}{l}{a}     -> dossier racine de l'animal
%   legend_table                       -> table issue de plot_selected_groups_overview
%   pooled_level                       -> largeur du pooling en jours pour le
%                                         panneau gauche (0/[] = aucun pooling).
%                                         Ex.: 5 ou '5' -> P7-P11, P12-P16, ...
%
% SORTIE :
%   figs.(type).type.(metric)
%   figs.(type).line.(line_key).(metric)
%   figs.(type).animal.(animal_key).medians (toutes les metriques sur une figure)
%
% Organisation des figures :
%   - ordre animal : UNE figure regroupant toutes les metriques, empilees
%                   verticalement (mediane +/- ecart-type par age)
%   - ordre lignee : une figure par metrique, mediane globale + individuelles
%   - ordre type   : une figure par metrique, mediane globale + individuelles
%   - pooled_level ne modifie QUE le panneau gauche des figures type/lignee.
%     Le panneau droit conserve les ages reels de chaque animal.
% Aucune figure de distribution / violons n'est creee ici.
%
% Pour l'ordre lignee, les medianes individuelles sont colorees par animal,
% reliees entre tous leurs ages mesures (meme non contigus), avec une legende par animal.
% Leurs ecarts-types sont representes par des bandeaux semi-transparents.
%
% Pour l'ordre type : les medianes individuelles sans bandeau SD ;
% la legende d'origine affiche aussi la lignee.

    figs = struct();

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2
        include_electroporated = false; %#ok<NASGU>
    end

    if nargin < 4 || isempty(output_folders_line)
        error('output_folders_line must be provided.');
    end

    if nargin < 3 || isempty(output_folders_type)
        error('output_folders_type must be provided.');
    end

    if nargin < 5 || isempty(output_folders_animal)
        error('output_folders_animal must be provided.');
    end

    if nargin < 6 || isempty(legend_table)
        legend_table = initialize_empty_legend_table();
    end

    if nargin < 7 || isempty(pooled_level)
        pooled_level = 0;
    end
    pooled_level = normalize_pooled_level(pooled_level);

    if ~isstruct(selected_groups)
        error('selected_groups must be a structure.');
    end

    defs = gcamp_metric_definitions();
    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};
        groups = selected_groups.(current_type);

        if isempty(groups)
            continue;
        end

        if t > numel(output_folders_type)
            warning('Missing output_folders_type for type %s.', current_type);
            continue;
        end

        type_folder = output_folders_type{t};
        if isempty(type_folder)
            warning('Empty output folder for type %s.', current_type);
            continue;
        end

        if exist(type_folder,'dir') ~= 7
            mkdir(type_folder);
        end

        line_values = strings(numel(groups),1);
        animal_values = strings(numel(groups),1);
        for k = 1:numel(groups)
            if isfield(groups(k),'line') && ~isempty(groups(k).line)
                line_values(k) = string(groups(k).line);
            end
            animal_values(k) = string(get_animal_name(groups(k),k));
        end

        unique_lines = unique(line_values,'stable');
        unique_lines(strlength(unique_lines)==0) = [];

        %==============================================================%
        % TYPE-LEVEL FIGURES
        %==============================================================%
        type_records = collect_basic_metric_records(groups);
        if ~isempty(type_records)
            type_records = type_records(isfinite([type_records.AgeValue]));
            if ~isempty(type_records)
                [~,order_idx] = sort([type_records.AgeValue]);
                type_records = type_records(order_idx);
                type_ages = unique([type_records.AgeValue],'sorted');

                for metric_idx = 1:numel(defs)
                    def = defs(metric_idx);
                    filename = sprintf('%s_%s_type_medians_by_age.png', ...
                        sanitize_filename_basic_metrics(current_type), def.Field);
                    out_path = fullfile(type_folder, filename);
                    type_key = matlab.lang.makeValidName(current_type);
                    figs.(type_key).type.(def.Field) = out_path;


                    try
                        figHandle = make_metric_figure( ...
                            type_records, type_ages, def, 'type', ...
                            current_type, '', '', legend_table, pooled_level);
                        if ~isempty(figHandle)
                            save_figure_png(figHandle, type_folder, filename);
                            if isgraphics(figHandle)
                                close(figHandle);
                            end
                        end
                    catch ME
                        warning('Type figure %s | %s: %s', ...
                            current_type, def.Field, ME.message);
                    end
                end
            end
        end

        %==============================================================%
        % LINE-LEVEL FIGURES
        %==============================================================%
        for l = 1:numel(unique_lines)

            current_line = char(unique_lines(l));
            line_mask = line_values == unique_lines(l);
            line_groups = groups(line_mask);

            if isempty(line_groups)
                continue;
            end

            if t > numel(output_folders_line) || l > numel(output_folders_line{t})
                warning('Missing output folder for %s | %s.', current_type, current_line);
                continue;
            end

            line_folder = output_folders_line{t}{l};
            if isempty(line_folder)
                warning('Empty output folder for %s | %s.', current_type, current_line);
                continue;
            end
            if exist(line_folder,'dir') ~= 7
                mkdir(line_folder);
            end

            line_records = collect_basic_metric_records(line_groups);
            if isempty(line_records)
                continue;
            end
            line_records = line_records(isfinite([line_records.AgeValue]));
            if isempty(line_records)
                continue;
            end
            [~,order_idx] = sort([line_records.AgeValue]);
            line_records = line_records(order_idx);
            line_ages = unique([line_records.AgeValue],'sorted');

            line_key = matlab.lang.makeValidName(current_line);
            for metric_idx = 1:numel(defs)
                def = defs(metric_idx);
                filename = sprintf('%s_%s_%s_line_medians_by_age.png', ...
                    sanitize_filename_basic_metrics(current_type), ...
                    sanitize_filename_basic_metrics(current_line), ...
                    def.Field);
                out_path = fullfile(line_folder, filename);
                figs.(matlab.lang.makeValidName(current_type)).line.(line_key).(def.Field) = out_path;


                try
                    figHandle = make_metric_figure( ...
                        line_records, line_ages, def, 'line', ...
                        current_type, current_line, '', legend_table, pooled_level);
                    if ~isempty(figHandle)
                        save_figure_png(figHandle, line_folder, filename);
                        if isgraphics(figHandle)
                            close(figHandle);
                        end
                    end
                catch ME
                    warning('Line figure %s | %s | %s: %s', ...
                        current_type, current_line, def.Field, ME.message);
                end
            end

            %==========================================================%
            % ANIMAL-LEVEL FIGURES
            %==========================================================%
            line_animal_values = strings(numel(line_groups),1);
            for a = 1:numel(line_groups)
                line_animal_values(a) = string(get_animal_name(line_groups(a),a));
            end
            unique_animals = unique(line_animal_values,'stable');
            unique_animals(strlength(unique_animals)==0) = [];

            for a = 1:numel(unique_animals)
                current_animal = char(unique_animals(a));
                animal_groups = line_groups(line_animal_values == unique_animals(a));
                if isempty(animal_groups)
                    continue;
                end

                animal_folder = '';
                if t <= numel(output_folders_animal) && ...
                        l <= numel(output_folders_animal{t}) && ...
                        a <= numel(output_folders_animal{t}{l})
                    animal_folder = output_folders_animal{t}{l}{a};
                end
                if isempty(animal_folder)
                    warning('Missing animal folder for %s | %s | %s.', ...
                        current_type, current_line, current_animal);
                    continue;
                end
                if exist(animal_folder,'dir') ~= 7
                    mkdir(animal_folder);
                end

                animal_records = collect_basic_metric_records(animal_groups);
                if isempty(animal_records)
                    continue;
                end
                animal_records = animal_records(isfinite([animal_records.AgeValue]));
                if isempty(animal_records)
                    continue;
                end
                [~,order_idx] = sort([animal_records.AgeValue]);
                animal_records = animal_records(order_idx);
                animal_ages = unique([animal_records.AgeValue],'sorted');

                % Une seule figure pour cet animal : une metrique par ligne.
                % Un nouveau nom evite de confondre la synthese avec les
                % anciens PNG individuels, qui ne sont pas modifies.
                animal_key = matlab.lang.makeValidName( ...
                    sprintf('%s__%s', current_line, current_animal));
                filename = sprintf('%s_%s_%s_animal_all_metrics_medians_by_age.png', ...
                    sanitize_filename_basic_metrics(current_type), ...
                    sanitize_filename_basic_metrics(current_line), ...
                    sanitize_filename_basic_metrics(current_animal));
                out_path = fullfile(animal_folder, filename);
                type_key = matlab.lang.makeValidName(current_type);


                figHandle = [];
                try
                    figHandle = make_animal_metrics_figure( ...
                        animal_records, animal_ages, defs, ...
                        current_type, current_line, current_animal);
                    if ~isempty(figHandle)
                        save_figure_png(figHandle, animal_folder, filename);
                    end
                    if exist(out_path,'file') == 2
                        figs.(type_key).animal.(animal_key).medians = out_path;
                    end
                catch ME
                    warning('Animal figure %s | %s | %s: %s', ...
                        current_type, current_line, current_animal, ME.message);
                end
                if ~isempty(figHandle) && isgraphics(figHandle)
                    close(figHandle);
                end
            end
        end
    end
end


%==========================================================================
% SYNTHESE ANIMALE : une figure, toutes les metriques empilees.
%==========================================================================
function figHandle = make_animal_metrics_figure( ...
        records, ages, defs, current_type, current_line, current_animal)

    figHandle = [];
    if isempty(records) || isempty(ages) || isempty(defs)
        return;
    end

    % Ne pas generer une figure entierement vide.
    median_matrix = nan(numel(ages), numel(defs));
    std_matrix = nan(numel(ages), numel(defs));
    for metric_idx = 1:numel(defs)
        [~, ~, medians, stds] = collect_metric_by_age( ...
            records, ages, defs(metric_idx).Field);
        median_matrix(:,metric_idx) = medians(:);
        std_matrix(:,metric_idx) = stds(:);
    end
    if ~any(isfinite(median_matrix(:)))
        return;
    end

    nMetrics = numel(defs);
    figHeight = max(250 * nMetrics, 900);
    figHandle = figure('Color','w', ...
        'Name', sprintf('%s_%s_%s_all_metrics_medians', ...
            current_type, current_line, current_animal), ...
        'Units','pixels', 'Position',[40 40 1100 figHeight]);
    tl = tiledlayout(figHandle, nMetrics, 1, ...
        'TileSpacing','compact', 'Padding','compact');
    title(tl, sprintf('%s | %s | %s - GCaMP medianes par age', ...
        current_type, current_line, current_animal), ...
        'Interpreter','none', 'FontWeight','bold', 'FontSize',17);

    for metric_idx = 1:nMetrics
        ax = nexttile(tl);
        hold(ax,'on');
        medians = median_matrix(:,metric_idx);
        stds = std_matrix(:,metric_idx);
        if any(isfinite(medians))
            plot_median_with_std_band(ax, ages, medians, stds, [0 0 0]);
        else
            text(ax, 0.5, 0.5, 'No GCaMP data', ...
                'Units','normalized', ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle');
        end
        format_age_axis(ax, ages);
        title(ax, defs(metric_idx).Name, ...
            'Interpreter','none', 'FontWeight','bold', 'FontSize',11);
        ylabel(ax, defs(metric_idx).Unit, 'Interpreter','none');
        if metric_idx == nMetrics
            xlabel(ax, 'Age');
        else
            set(ax, 'XTickLabel', []);
        end
        grid(ax,'on');
    end
end


%==========================================================================
% FIGURE UNE METRIQUE
%==========================================================================
function figHandle = make_metric_figure(records, ages, def, order_mode, ...
        current_type, current_line, current_animal, legend_table, pooled_level)

    if isempty(records) || isempty(ages)
        figHandle = [];
        return;
    end

    % Le panneau droit reste toujours sur les ages reels.
    % Le panneau gauche peut regrouper plusieurs jours.
    if pooled_level > 0
        [left_ages, left_labels, medians, stds] = ...
            collect_metric_by_pooled_age(records, ages, def.Field, pooled_level);
    else
        [~, ~, medians, stds] = ...
            collect_metric_by_age(records, ages, def.Field);
        left_ages = ages(:);
        left_labels = cellstr(compose('P%g', left_ages));
    end

    if ~any(isfinite(medians))
        figHandle = [];
        return;
    end

    if strcmpi(order_mode,'animal')
        nCols = 1;
        width_px = 1000;
    else
        nCols = 2;
        width_px = 1650;
    end

    figHandle = figure('Color','w', ...
        'Name', sprintf('%s_%s_%s', current_type, def.Field, order_mode), ...
        'Units','pixels', 'Position',[30 60 width_px 760]);

    tl = tiledlayout(figHandle,1,nCols,'TileSpacing','compact','Padding','compact');
    title(tl, build_metric_figure_title(current_type, current_line, current_animal, def.Name, order_mode), ...
        'Interpreter','none', 'FontWeight','bold', 'FontSize',16);

    %--------------------------------------------------------------%
    % 1) MEDIANE GLOBALE + BANDEAU ECART-TYPE
    %--------------------------------------------------------------%
    ax1 = nexttile(tl,1);
    hold(ax1,'on');
    plot_median_with_std_band(ax1, left_ages, medians, stds, [0 0 0]);

    if pooled_level > 0
        format_custom_age_axis(ax1, left_ages, left_labels);
        title(ax1, sprintf( ...
            'Mediane globale par fenetre de %g jours +/- ecart-type', ...
            pooled_level), ...
            'FontWeight','bold');
    else
        format_age_axis(ax1, left_ages);
        title(ax1, 'Mediane globale par age +/- ecart-type', ...
            'FontWeight','bold');
    end

    ylabel(ax1, def.Unit, 'Interpreter','none', 'FontWeight','bold');
    xlabel(ax1, 'Age');
    grid(ax1,'on');

    %--------------------------------------------------------------%
    % 2) MEDIANES INDIVIDUELLES : TYPE ET LIGNEE UNIQUEMENT
    %--------------------------------------------------------------%
    if nCols == 2
        ax2 = nexttile(tl,2);
        hold(ax2,'on');
        animal_stats = collect_individual_animal_stats(records, ages, def.Field, ...
            current_type, current_line, legend_table, order_mode);
        plot_individual_animal_medians(ax2, animal_stats, ages, order_mode);
        format_age_axis(ax2, ages);
        ylabel(ax2, def.Unit, 'Interpreter','none', 'FontWeight','bold');
        xlabel(ax2, 'Age');
        if strcmpi(order_mode,'line')
            title(ax2, 'Medianes par animal +/- ecart-type', 'FontWeight','bold');
        else
            title(ax2, 'Medianes par animal (lignee dans la legende)', 'FontWeight','bold');
        end
        grid(ax2,'on');
    end
end

function title_str = build_metric_figure_title(current_type, current_line, current_animal, metric_name, order_mode)
    switch lower(order_mode)
        case 'type'
            title_str = sprintf('%s | %s | by type', current_type, metric_name);
        case 'line'
            title_str = sprintf('%s | %s | %s | by line', current_type, current_line, metric_name);
        case 'animal'
            title_str = sprintf('%s | %s | %s | %s | by animal', ...
                current_type, current_line, current_animal, metric_name);
        otherwise
            title_str = sprintf('%s | %s', current_type, metric_name);
    end
end


%==========================================================================
% COLLECTE DES RECORDS GCaMP
%==========================================================================
function records = collect_basic_metric_records(animals)

    template = struct( ...
        'Type', '', ...
        'Line', '', ...
        'Animal', '', ...
        'Date', '', ...
        'AgeRaw', [], ...
        'AgeValue', NaN, ...
        'Frequency', [], ...
        'Correlation', [], ...
        'Coupling', [], ...
        'BurstCellProportion', [], ...
        'MeanBurstsPerCell', [], ...
        'SCEFrequency', [], ...
        'SCEParticipation', []);

    records = repmat(template,0,1);

    for k = 1:numel(animals)

        animal_struct = animals(k);

        if ~isfield(animal_struct,'results_analysis') || ...
                isempty(animal_struct.results_analysis) || ...
                ~isstruct(animal_struct.results_analysis)
            continue;
        end

        if ~isfield(animal_struct,'ages') || isempty(animal_struct.ages)
            continue;
        end

        if ~isfield(animal_struct,'dates') || isempty(animal_struct.dates)
            continue;
        end

        current_results = animal_struct.results_analysis;
        current_ages = normalize_record_cell(animal_struct.ages, inf);
        current_dates = normalize_record_cell(animal_struct.dates, inf);

        nRec_results = infer_nrec_from_current_results(current_results);
        nRec = max([numel(current_ages), numel(current_dates), nRec_results]);

        if nRec == 0
            continue;
        end

        current_ages = normalize_record_cell(current_ages, nRec);
        current_dates = normalize_record_cell(current_dates, nRec);

        animal_name = get_animal_name(animal_struct, k);
        line_name = '';
        if isfield(animal_struct,'line') && ~isempty(animal_struct.line)
            line_name = char(string(animal_struct.line));
        end
        type_name = '';
        if isfield(animal_struct,'type') && ~isempty(animal_struct.type)
            type_name = char(string(animal_struct.type));
        end

        for m = 1:nRec
            rec = template;
            rec.Type = type_name;
            rec.Line = line_name;
            rec.Animal = animal_name;
            rec.Date = value_to_text(get_record_value(current_dates,m));
            rec.AgeRaw = get_record_value(current_ages,m);
            rec.AgeValue = parse_one_age(rec.AgeRaw);

            rec.Frequency = get_nested_record_value(current_results, ...
                {'gcamp_plane','activity','FrequencyPerCell'}, m, nRec);
            rec.Correlation = get_nested_record_value(current_results, ...
                {'gcamp_plane','correlations','max_corr_gcamp_gcamp_by_plane'}, m, nRec);
            rec.Coupling = get_nested_record_value(current_results, ...
                {'gcamp_plane','coupling','coupling_gcamp_gcamp_by_plane'}, m, nRec);
            rec.BurstCellProportion = get_nested_record_value(current_results, ...
                {'gcamp_plane','activity','BurstCellProportion'}, m, nRec);
            rec.MeanBurstsPerCell = get_nested_record_value(current_results, ...
                {'gcamp_plane','activity','MeanBurstsPerCell'}, m, nRec);
            rec.SCEFrequency = get_nested_record_value(current_results, ...
                {'gcamp_plane','SCEs','Frequency'}, m, nRec);
            rec.SCEParticipation = get_nested_record_value(current_results, ...
                {'gcamp_plane','SCEs','CellParticipation_percent'}, m, nRec);

            records(end+1,1) = rec; %#ok<AGROW>
        end
    end
end


%==========================================================================
% DEFINITIONS DES METRIQUES GCaMP
%==========================================================================
function defs = gcamp_metric_definitions()
    defs = struct( ...
        'Field', { ...
            'Frequency', 'Correlation', 'Coupling', ...
            'BurstCellProportion', 'MeanBurstsPerCell', ...
            'SCEFrequency', 'SCEParticipation'}, ...
        'Name', { ...
            'Activity frequency', 'Maximum Pearson correlation', 'Coupling (+/- 0.5 s)', ...
            'Cells with >= 1 burst', 'Mean bursts per cell', ...
            'SCE frequency', 'SCE participation'}, ...
        'Unit', { ...
            'events / min / cell', 'Pearson r', 'correlation', ...
            'proportion', 'bursts / cell', ...
            'SCE / min', '%'});
end


%==========================================================================
% PAR AGE
%==========================================================================
function [by_age, animals_by_age, medians, stds] = collect_metric_by_age(records, ages, field_name)
    nAges = numel(ages);
    by_age = cell(nAges,1);
    animals_by_age = cell(nAges,1);
    medians = nan(nAges,1);
    stds = nan(nAges,1);

    for a = 1:nAges
        age_mask = [records.AgeValue] == ages(a);
        age_records = records(age_mask);
        values = [];
        animal_list = strings(0,1);

        for r = 1:numel(age_records)
            v = flatten_metric_values(age_records(r).(field_name));
            if isempty(v)
                continue;
            end
            values = [values; v(:)]; %#ok<AGROW>
            animal_list(end+1,1) = string(age_records(r).Animal); %#ok<AGROW>
        end

        values = values(isfinite(values));
        by_age{a} = values;
        animals_by_age{a} = unique(animal_list,'stable');

        if ~isempty(values)
            medians(a) = median(values, 'omitnan');
            if numel(values) >= 2
                stds(a) = std(values, 0, 'omitnan');
            else
                stds(a) = 0;
            end
        end
    end
end


%==========================================================================
% POOLING DE LA MEDIANE GLOBALE PAR FENETRES D'AGE
%==========================================================================
function [pool_x, pool_labels, medians, stds] = ...
        collect_metric_by_pooled_age(records, ages, field_name, pooled_level)

    pool_x = [];
    pool_labels = {};
    medians = [];
    stds = [];

    ages = unique(ages(isfinite(ages)), 'sorted');
    if isempty(ages)
        return;
    end

    pooled_level = normalize_pooled_level(pooled_level);
    if pooled_level <= 0
        [~, ~, medians, stds] = ...
            collect_metric_by_age(records, ages, field_name);
        pool_x = ages(:);
        pool_labels = cellstr(compose('P%g', pool_x));
        return;
    end

    first_age = min(ages);
    last_age = max(ages);

    % Les fenetres sont ancrees sur le plus jeune age effectivement present.
    % Exemple si min(age)=7 et pooled_level=5 :
    %   P7-P11, P12-P16, P17-P21, ...
    pool_starts = first_age:pooled_level:last_age;
    nPools = numel(pool_starts);

    pool_x = nan(nPools,1);
    pool_labels = cell(nPools,1);
    medians = nan(nPools,1);
    stds = nan(nPools,1);

    for b = 1:nPools
        lo = pool_starts(b);
        hi = lo + pooled_level - 1;
        pool_x(b) = lo + (pooled_level - 1)/2;

        if pooled_level == 1
            pool_labels{b} = sprintf('P%g', lo);
        else
            pool_labels{b} = sprintf('P%g-P%g', lo, hi);
        end

        in_pool = [records.AgeValue] >= lo & ...
                  [records.AgeValue] < lo + pooled_level;
        pool_records = records(in_pool);

        values = [];
        for r = 1:numel(pool_records)
            v = flatten_metric_values(pool_records(r).(field_name));
            if ~isempty(v)
                values = [values; v(:)]; %#ok<AGROW>
            end
        end

        values = values(isfinite(values));
        if isempty(values)
            continue;
        end

        medians(b) = median(values, 'omitnan');
        if numel(values) >= 2
            stds(b) = std(values, 0, 'omitnan');
        else
            stds(b) = 0;
        end
    end
end


%==========================================================================
% VALIDATION DU NIVEAU DE POOLING
%==========================================================================
function pooled_level = normalize_pooled_level(pooled_level)

    if isempty(pooled_level)
        pooled_level = 0;
        return;
    end

    if isstring(pooled_level) || ischar(pooled_level)
        if numel(string(pooled_level)) ~= 1
            error('pooled_level doit etre un scalaire.');
        end
        pooled_level = str2double(string(pooled_level));
    elseif isnumeric(pooled_level) || islogical(pooled_level)
        pooled_level = double(pooled_level);
    else
        error('pooled_level doit etre numerique, char ou string.');
    end

    if ~isscalar(pooled_level) || ~isfinite(pooled_level) || pooled_level < 0
        error('pooled_level doit etre un scalaire fini >= 0.');
    end

    if pooled_level > 0 && pooled_level ~= round(pooled_level)
        error('pooled_level doit etre un nombre entier de jours.');
    end

    pooled_level = round(pooled_level);
end


%==========================================================================
% STATS PAR ANIMAL ET PAR AGE
%==========================================================================
function animal_stats = collect_individual_animal_stats(records, ages, field_name, ...
        current_type, current_line, legend_table, order_mode)

    animal_names = strings(numel(records),1);
    line_names = strings(numel(records),1);
    for i = 1:numel(records)
        animal_names(i) = string(records(i).Animal);
        if isfield(records(i),'Line') && ~isempty(records(i).Line)
            line_names(i) = string(records(i).Line);
        end
    end

    % Identifier un animal par sa lignee ET son numero. Sinon, au niveau
    % type, deux lignees ayant le meme numero d'animal sont fusionnees.
    animal_keys = line_names + " | " + animal_names;
    animal_keys(strlength(animal_names) == 0) = "";
    unique_keys = unique(animal_keys, 'stable');
    unique_keys(strlength(unique_keys) == 0) = [];

    animal_stats = repmat(struct( ...
        'animal','', ...
        'line','', ...
        'display_label','', ...
        'legend_label','', ...
        'color',[0.4 0.4 0.4], ...
        'ages',ages(:), ...
        'medians',nan(numel(ages),1), ...
        'stds',nan(numel(ages),1)), numel(unique_keys),1);

    for i = 1:numel(unique_keys)
        idx_this = find(animal_keys == unique_keys(i));
        if isempty(idx_this)
            continue;
        end
        animal_name = char(animal_names(idx_this(1)));
        recs = records(idx_this);
        line_name = '';
        if ~isempty(recs(1).Line)
            line_name = recs(1).Line;
        elseif ~isempty(current_line)
            line_name = current_line;
        end

        [display_label, color] = get_legend_display_and_color( ...
            legend_table, current_type, line_name, animal_name);
        if isempty(display_label)
            display_label = animal_name;
        end

        if strcmpi(order_mode,'type')
            legend_label = sprintf('%s', display_label);
        else
            legend_label = display_label;
        end

        stats = animal_stats(i);
        stats.animal = animal_name;
        stats.line = line_name;
        stats.display_label = display_label;
        stats.legend_label = legend_label;
        stats.color = color;

        for a = 1:numel(ages)
            vals = [];
            for r = 1:numel(recs)
                if recs(r).AgeValue ~= ages(a)
                    continue;
                end
                v = flatten_metric_values(recs(r).(field_name));
                if isempty(v)
                    continue;
                end
                vals = [vals; v(:)]; %#ok<AGROW>
            end
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                stats.medians(a) = median(vals, 'omitnan');
                if numel(vals) >= 2
                    stats.stds(a) = std(vals, 0, 'omitnan');
                else
                    stats.stds(a) = 0;
                end
            end
        end

        animal_stats(i) = stats;
    end
end


%==========================================================================
% TRACES DES MEDIANES INDIVIDUELLES + SD
%==========================================================================
function plot_individual_animal_medians(ax, animal_stats, ages, order_mode)

    if nargin < 4
        order_mode = 'line';
    end

    handles = gobjects(0,1);
    labels = cell(0,1);
    band_alpha = 0.18;

    for i = 1:numel(animal_stats)
        stats = animal_stats(i);
        x = ages(:);
        y = stats.medians(:);
        s = stats.stds(:);

        % Conserver tous les ages mesures pour cet animal : un age
        % intermediaire absent ne doit pas couper sa trajectoire.
        good = isfinite(x) & isfinite(y);
        if ~any(good)
            continue;
        end

        xx = x(good);
        yy = y(good);
        ss = s(good);
        ss(~isfinite(ss)) = 0;
        ss = max(ss, 0);

        % Ecart-type individuel UNIQUEMENT pour les figures par lignee.
        % La figure par type garde les courbes colorees sans bandeau.
        % Les bandeaux ne figurent jamais dans la legende originale.
        if strcmpi(order_mode, 'line')
            if numel(xx) >= 2
                patch(ax, [xx; flipud(xx)], ...
                    [yy + ss; flipud(yy - ss)], stats.color, ...
                    'FaceAlpha', band_alpha, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            elseif ss > 0
                % Un seul age : bande verticale de largeur non nulle.
                finite_ages = ages(isfinite(ages));
                if numel(finite_ages) > 1
                    sorted_ages = unique(sort(finite_ages(:)));
                    dx = min(diff(sorted_ages)) * 0.12;
                else
                    dx = 0.18;
                end
                patch(ax, xx + [-dx; dx; dx; -dx], ...
                    yy + [-ss; -ss; ss; ss], stats.color, ...
                    'FaceAlpha', band_alpha, ...
                    'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
        end

        % Une courbe par animal, y compris entre deux ages distants.
        h = plot(ax, xx, yy, '-o', ...
            'Color', stats.color, ...
            'MarkerEdgeColor', stats.color, ...
            'MarkerFaceColor', 'w', ...
            'LineWidth', 1.8, ...
            'MarkerSize', 6, ...
            'DisplayName', stats.legend_label);

        handles(end+1,1) = h; %#ok<AGROW>
        labels{end+1,1} = stats.legend_label; %#ok<AGROW>
    end

    if isempty(handles)
        text(ax,0.5,0.5,'No individual data', ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle');
        return;
    end

    [~, ia] = unique(labels, 'stable');
    handles = handles(ia);
    labels = labels(ia);
    if strcmpi(order_mode,'type')
        legend(ax, handles, labels, 'Location','eastoutside', 'Interpreter','none');
    else
        legend(ax, handles, labels, 'Location','best', 'Interpreter','none');
    end
end


%==========================================================================
% MEDIANE GLOBALE + BANDEAU SD
%==========================================================================
function plot_median_with_std_band(ax, ages, medians, stds, line_color)

    x = ages(:);
    y = medians(:);
    s = stds(:);

    if nargin < 5 || isempty(line_color)
        line_color = [0 0 0];
    end

    good = isfinite(x) & isfinite(y);
    if ~any(good)
        text(ax,0.5,0.5,'No data', ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle');
        return;
    end

    s(~isfinite(s)) = 0;
    good_idx = find(good);
    run_breaks = [1; find(diff(good_idx) > 1) + 1; numel(good_idx) + 1];

    for r = 1:numel(run_breaks)-1
        idx = good_idx(run_breaks(r):run_breaks(r+1)-1);
        xx = x(idx);
        yy = y(idx);
        ss = s(idx);
        patch(ax, [xx; flipud(xx)], [yy+ss; flipud(yy-ss)], ...
            line_color, 'FaceAlpha',0.15, 'EdgeColor','none', ...
            'HandleVisibility','off');
        plot(ax, xx, yy, '-o', ...
            'Color', line_color, ...
            'MarkerEdgeColor', line_color, ...
            'MarkerFaceColor', 'w', ...
            'LineWidth', 2, ...
            'MarkerSize', 6);
    end
end


%==========================================================================
% FORMAT AXE AGE POUR LE POOLING
%==========================================================================
function format_custom_age_axis(ax, x_values, labels)

    if isempty(x_values)
        return;
    end

    x_values = x_values(:)';
    labels = labels(:)';

    good = isfinite(x_values);
    x_values = x_values(good);
    labels = labels(good);

    if isempty(x_values)
        return;
    end

    if numel(x_values) == 1
        xlim(ax, [x_values(1)-1, x_values(1)+1]);
    else
        total_range = max(x_values) - min(x_values);
        padding = max(1, 0.08 * total_range);
        xlim(ax, [min(x_values)-padding, max(x_values)+padding]);
    end

    set(ax, ...
        'XTick', x_values, ...
        'XTickLabel', labels, ...
        'TickDir', 'out', ...
        'FontSize', 8, ...
        'TickLabelInterpreter', 'none');

    xtickangle(ax, 45);
    box(ax, 'off');
end


%==========================================================================
% FORMAT AXE AGE
%==========================================================================
function format_age_axis(ax, ages)
    if isempty(ages)
        return;
    end

    ages = unique(ages(isfinite(ages)), 'sorted');
    ages = ages(:)';
    if isempty(ages)
        return;
    end

    if numel(ages) == 1
        xlim(ax, [ages(1)-1, ages(1)+1]);
    else
        total_age_range = max(ages) - min(ages);
        padding = max(1, 0.03 * total_age_range);
        xlim(ax, [min(ages)-padding, max(ages)+padding]);
    end

    % Afficher les ages reels (sans modifier la position des points).
    labels = cellstr(compose('P%g', ages));

    % Plus d'inclinaison et police reduite pour gagner de la place.
    % Si les ages sont vraiment trop serres, ne masquer que certains
    % TEXTES : toutes les graduations et toutes les mesures restent.
    set(ax, 'XTick', ages, 'TickDir', 'out', ...
        'FontSize', 8, 'TickLabelInterpreter', 'none');
    xtickangle(ax, 70);

    if numel(ages) > 2
        drawnow;  % dimensions reelles apres mise en page et legende
        ax_px = getpixelposition(ax, true);
        axis_limits = xlim(ax);
        axis_width = max(1, ax_px(3));
        x_px = (ages - axis_limits(1)) / diff(axis_limits) * axis_width;

        % Largeur de securite pour les textes inclines P7, P12, P100...
        % (on conserve en priorite les premiers/derniers ages).
        min_gap_px = 17;
        keep = false(size(ages));
        keep([1 end]) = true;
        last_kept = 1;
        for k = 2:numel(ages)-1
            if x_px(k) - x_px(last_kept) >= min_gap_px && ...
                    x_px(end) - x_px(k) >= min_gap_px
                keep(k) = true;
                last_kept = k;
            end
        end
        labels(~keep) = {''};
    end

    set(ax, 'XTickLabel', labels);
    box(ax, 'off');
end

%==========================================================================
% HELPERS DE LEGENDE
%==========================================================================
function [display_label, color] = get_legend_display_and_color(legend_table, type_name, line_name, animal_name)
    display_label = '';
    color = [0.45 0.45 0.45];

    if isempty(legend_table) || ~istable(legend_table)
        display_label = animal_name;
        return;
    end

    required_vars = {'Type','Line','Animal','DisplayAnimal','Red','Green','Blue'};
    if ~all(ismember(required_vars, legend_table.Properties.VariableNames))
        display_label = animal_name;
        return;
    end

    rows = string(legend_table.Type) == string(type_name) & ...
           string(legend_table.Line) == string(line_name) & ...
           string(legend_table.Animal) == string(animal_name);

    idx = find(rows, 1, 'first');
    if isempty(idx)
        % Fallback sans contrainte sur la ligne.
        rows = string(legend_table.Type) == string(type_name) & ...
               string(legend_table.Animal) == string(animal_name);
        idx = find(rows, 1, 'first');
    end

    if isempty(idx)
        display_label = animal_name;
        return;
    end

    display_label = char(string(legend_table.DisplayAnimal(idx)));
    color = [legend_table.Red(idx), legend_table.Green(idx), legend_table.Blue(idx)];
    if any(~isfinite(color))
        color = [0.45 0.45 0.45];
    end
end


function legend_table = initialize_empty_legend_table()
    legend_table = table( ...
        string.empty(0,1), ...
        string.empty(0,1), ...
        string.empty(0,1), ...
        string.empty(0,1), ...
        nan(0,1), nan(0,1), nan(0,1), ...
        'VariableNames', { ...
            'Type','Line','Animal','DisplayAnimal','Red','Green','Blue'});
end


%==========================================================================
% APLATIR UNE METRIQUE
%==========================================================================
function vals = flatten_metric_values(x)
    vals = [];

    if isempty(x)
        return;
    end

    if iscell(x)
        for i = 1:numel(x)
            current_vals = flatten_metric_values(x{i});
            if ~isempty(current_vals)
                vals = [vals; current_vals(:)]; %#ok<AGROW>
            end
        end
        return;
    end

    if isstruct(x)
        return;
    end

    if ~(isnumeric(x) || islogical(x))
        return;
    end

    x = double(x(:));
    vals = x(isfinite(x));
end


%==========================================================================
% GET NESTED RECORD VALUE
%==========================================================================
function value = get_nested_record_value(S, path_fields, idx, nRec)

    value = [];
    x = get_nested_field_or_empty(S, path_fields);
    if isempty(x)
        return;
    end

    if iscell(x)
        if isvector(x)
            if numel(x) >= idx
                value = x{idx};
            end
            return;
        end
        if size(x,1) == nRec && idx <= size(x,1)
            value = x(idx,:);
            return;
        end
        if numel(x) >= idx
            value = x{idx};
        end
        return;
    end

    if isstring(x)
        if numel(x) >= idx
            value = x(idx);
        elseif idx == 1
            value = x;
        end
        return;
    end

    if isnumeric(x) || islogical(x)
        if ~isvector(x) && size(x,1) == nRec && idx <= size(x,1)
            value = x(idx,:);
            return;
        end
        if isvector(x) && numel(x) == nRec
            value = x(idx);
            return;
        end
        if idx == 1
            value = x;
        end
        return;
    end

    if idx == 1
        value = x;
    end
end


%==========================================================================
% GET NESTED FIELD
%==========================================================================
function x = get_nested_field_or_empty(S, path_fields)
    x = [];
    current = S;
    for i = 1:numel(path_fields)
        fn = path_fields{i};
        if ~isstruct(current) || ~isfield(current, fn)
            return;
        end
        current = current.(fn);
    end
    x = current;
end


%==========================================================================
% NOMBRE DE RECORDINGS
%==========================================================================
function nRec = infer_nrec_from_current_results(results_analysis)
    nRec = 0;

    candidate_paths = { ...
        {'gcamp_plane','activity','FrequencyPerCell'}, ...
        {'gcamp_plane','correlations','max_corr_gcamp_gcamp_by_plane'}, ...
        {'gcamp_plane','coupling','coupling_gcamp_gcamp_by_plane'}, ...
        {'gcamp_plane','activity','BurstCellProportion'}, ...
        {'gcamp_plane','activity','MeanBurstsPerCell'}, ...
        {'gcamp_plane','SCEs','Frequency'}, ...
        {'gcamp_plane','SCEs','CellParticipation_percent'} ...
    };

    for i = 1:numel(candidate_paths)
        x = get_nested_field_or_empty(results_analysis, candidate_paths{i});
        if isempty(x)
            continue;
        end
        if iscell(x) || isstring(x)
            if isvector(x)
                nRec = max(nRec, numel(x));
            else
                nRec = max(nRec, size(x,1));
            end
        elseif isnumeric(x) || islogical(x)
            if isvector(x)
                nRec = max(nRec, numel(x));
            else
                nRec = max(nRec, size(x,1));
            end
        end
    end
end


%==========================================================================
% NORMALISER RECORD CELL
%==========================================================================
function C = normalize_record_cell(C, nRec)

    if ~iscell(C)
        if isstring(C)
            C = cellstr(C(:));
        elseif isnumeric(C) || islogical(C)
            C = num2cell(C(:));
        elseif ischar(C)
            C = {C};
        else
            C = {C};
        end
    else
        C = C(:);
    end

    if isinf(nRec)
        return;
    end

    if numel(C) < nRec
        C(end+1:nRec,1) = {[]};
    elseif numel(C) > nRec
        C = C(1:nRec);
    end
end


%==========================================================================
% GET RECORD VALUE
%==========================================================================
function value = get_record_value(C, idx)
    value = [];
    if isempty(C) || idx > numel(C)
        return;
    end
    if iscell(C)
        value = C{idx};
    else
        value = C(idx);
    end
end


%==========================================================================
% PARSE AGE
%==========================================================================
function age_value = parse_one_age(age_raw)
    age_value = NaN;

    if isempty(age_raw)
        return;
    end

    if isnumeric(age_raw) || islogical(age_raw)
        age_raw = double(age_raw);
        if isscalar(age_raw) && isfinite(age_raw)
            age_value = age_raw;
        end
        return;
    end

    if iscell(age_raw)
        if ~isempty(age_raw)
            age_value = parse_one_age(age_raw{1});
        end
        return;
    end

    if isstring(age_raw) || ischar(age_raw)
        tok = regexp(char(age_raw), '\d+(\.\d+)?', 'match', 'once');
        if ~isempty(tok)
            age_value = str2double(tok);
        end
    end
end


%==========================================================================
% VALUE TO TEXT
%==========================================================================
function txt = value_to_text(x)
    txt = '';
    if isempty(x)
        return;
    end
    if iscell(x)
        if ~isempty(x)
            txt = value_to_text(x{1});
        end
        return;
    end
    if isdatetime(x)
        txt = char(string(x));
        return;
    end
    if isstring(x)
        if ~isempty(x)
            txt = char(x(1));
        end
        return;
    end
    if ischar(x)
        txt = x;
        return;
    end
    if isnumeric(x) || islogical(x)
        if isscalar(x)
            txt = char(string(x));
        end
    end
end


%==========================================================================
% ANIMAL NAME
%==========================================================================
function animal_name = get_animal_name(animal_struct, fallback_idx)
    animal_name = sprintf('animal_%d', fallback_idx);
    candidate_fields = {'animal','animal_group','name'};
    for i = 1:numel(candidate_fields)
        fn = candidate_fields{i};
        if isfield(animal_struct, fn) && ~isempty(animal_struct.(fn))
            animal_name = char(string(animal_struct.(fn)));
            return;
        end
    end
end


%==========================================================================
% CLEAN NUMERIC
%==========================================================================
function x = clean_numeric(x)
    if isempty(x) || ~(isnumeric(x) || islogical(x))
        x = [];
        return;
    end
    x = double(x(:));
    x = x(isfinite(x));
end


%==========================================================================
% SANITIZE FILENAME
%==========================================================================
function safe_name = sanitize_filename_basic_metrics(input_name)
    safe_name = char(string(input_name));
    safe_name = regexprep(safe_name, '[<>:"/\\|?*]', '_');
    safe_name = strrep(safe_name, ' ', '_');
end


%==========================================================================
% SAVE FIGURE
%==========================================================================
function save_figure_png(figHandle, save_folder, filename)
    if isempty(figHandle) || ~ishghandle(figHandle)
        return;
    end

    if exist(save_folder,'dir') ~= 7
        mkdir(save_folder);
    end

    output_path = fullfile(save_folder, filename);

    % Conserver la taille de la figure, notamment pour les panneaux
    % verticaux de la synthese animale.
    drawnow;

    try
        exportgraphics(figHandle, output_path, 'Resolution', 300);
    catch
        saveas(figHandle, output_path);
    end

    fprintf('Figure saved: %s\n', output_path);
end
