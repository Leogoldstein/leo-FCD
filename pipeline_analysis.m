%If you want to retrieve datas
clearvars
PathSave = 'D:/after_processing/Synchrony peaks/FCD';
[directories] = retrieve_results(PathSave);
[dataFolders, animal_date_list, results] = load_results(directories);

process_data(all_DF, all_ops, all_isort1, all_MAct, animal_date_list) 