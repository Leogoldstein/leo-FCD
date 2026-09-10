% ============================================================
% INITIALISATION
% ============================================================

clearvars -except choices group_order selected_groups

clc

setup_python_env()

if ~exist('selected_groups', 'var')

    selected_groups = [];

end


% ============================================================
% CHOIX DU TYPE
% ============================================================

[choices, group_order] = ...
    choose_group_selection();


% ============================================================
% CHOIX DES DOSSIERS / MODE DE SÉLECTION
% ============================================================

[root_folders, selected_folders, include_electroporated, ...
    automatic_selection, selection_mode, age_group] = ...
    select_data_folders_by_group( ...
        choices, ...
        group_order);


% ============================================================
% RECHARGEMENT ÉVENTUEL DU DERNIER selected_groups
% ============================================================

[selected_groups, selected_groups_reloaded] = ...
    load_last_selected_groups( ...
        root_folders, ...
        choices, ...
        group_order, ...
        selection_mode, ...
        age_group, ...
        include_electroporated);


% ============================================================
% CONSTRUCTION ET DATA PROCESSING
%
% Ignoré si selected_groups a été rechargé
% ============================================================

if ~selected_groups_reloaded

    % --------------------------------------------------------
    % CONSTRUCTION / MISE À JOUR DE LA SÉLECTION
    % ---------------------------------------------------------

    [selected_groups, animal_date_list] = ...
        folder_selection( ...
            choices, ...
            group_order, ...
            selected_folders, ...
            selected_groups, ...
            automatic_selection, ...
            include_electroporated, ...
            age_group);


    % --------------------------------------------------------
    % CRÉATION DES STRUCTURES DE DONNÉES
    % ---------------------------------------------------------

    selected_groups = ...
        create_data( ...
            selected_groups);


    % --------------------------------------------------------
    % MÉTADONNÉES
    % ---------------------------------------------------------

    [selected_groups, metadata_table] = ...
        create_metadata( ...
            selected_groups);


    % recap_all = ...
    %     create_summary_sheets( ...
    %         selected_groups);


    % --------------------------------------------------------
    % DATA PROCESSING
    % ---------------------------------------------------------

    selected_groups = ...
        process_selected_groups( ...
            selected_groups, ...
            include_electroporated, ...
            automatic_selection);


    % --------------------------------------------------------
    % PEAK DETECTION
    % ---------------------------------------------------------

    selected_groups = ...
        DF_peak_detection( ...
            selected_groups, ...
            include_electroporated, ...
            automatic_selection);

end


% ============================================================
% CALCUL DES MÉTRIQUES DF
%
% Toujours exécuté, même après reload
% ============================================================

[selected_groups, results_table] = ...
    compute_DF( ...
        selected_groups, ...
        include_electroporated);


%% ============================================================
% SAUVEGARDE (lancer que si selected_groups a changé)
% ============================================================

save_selected_groups( ...
    selected_groups, ...
    root_folders, ...
    choices, ...
    group_order, ...
    age_group, ...
    selection_mode, ...
    include_electroporated);


%% ============================================================
% VISUALISATION
% ============================================================

visualize_data( ...
    selected_groups, ...
    automatic_selection, ...
    include_electroporated, ...
    results_table);



%%
[grouped_data_by_age, barplots] = barplots_by_type(selected_groups); % SCEs analysis required
    %%
corr_boxplots = corr_groups_boxplots_all(selected_groups); % correlation analysis required

%%


%%

figs = plot_by_type_no_age(selected_groups);
%%


%%
figs = RasterChange_around_SCEs(selected_groups);
figs = FiringRateChange_around_SCEs(selected_groups);



%%
close all
create_ppt_from_figs(selected_groups, daytime)

%%
which isempty

%%

