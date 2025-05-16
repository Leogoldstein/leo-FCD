%% Preprocessing

clear

% % Définir le chemin vers Python dans l'environnement Suite2p
% pyExec = "C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\python.exe";
% 
% % Initialiser pyenv uniquement s’il n’est pas encore chargé
% pe = pyenv;
% if pe.Status == "NotLoaded"
%     pyenv('Version', pyExec);
%     fprintf("pyenv défini sur l’environnement suite2p\n");
% else
%     fprintf("Python déjà chargé depuis : %s\n", pe.Executable);
% end

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/data preprocessing';

%Vérifiez si le 2che2min est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[animal_date_list, selected_groups] = pipeline_for_data_preprocessing();

% for idx = 1:length(env_paths_all)
%     [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(env_paths_all{idx});
%     disp(position)
% end

%%
[selected_groups, daytime] = process_selected_group(selected_groups);

%% Processing and analysis
[analysis_choices, selected_groups] = pipeline_for_data_processing(selected_groups, include_blue_cells);

%%
create_ppt_from_figs(selected_groups, daytime)
