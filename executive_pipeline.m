
%% Preprocessing

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/data preprocessing';
%Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[dataFolders, truedataFolders, animal_date_list, env_paths, env_paths_all] = pipeline_for_data_preprocessing();


%% Processing and analysis

PathSave = 'D:\after_processing';
pipeline_for_data_processing(PathSave, truedataFolders, animal_date_list, env_paths);