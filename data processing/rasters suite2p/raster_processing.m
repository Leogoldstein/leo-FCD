function [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, sampling_rate, synchronous_frames, directory)
    % Initialisation des sorties en cas d'erreur
    isort1 = [];
    isort2 = [];
    Sm = [];
    Raster = [];
    MAct = [];
    Acttmp2 = [];

    try 
        % Vérification de la taille de DF
        if isempty(DF) || size(DF, 1) < 2 || size(DF, 2) < 2
            error('DF est vide ou ses dimensions sont incorrectes.');
        end
        
        % Process raster plots
        [isort1, isort2, Sm] = processRasterPlots(DF, ops);

        % Vérification des dimensions avant de passer à Sumactivity
        if ~isempty(isort1) && ~isempty(isort2)
            % Vérification de la cohérence des dimensions
            if size(DF, 1) ~= size(isort1, 1)
                error('Dimension mismatch: DF et isort1 doivent avoir le même nombre de lignes.');
            end

            % Calcul des activités et du raster
            [Raster, MAct, Acttmp2] = Sumactivity(DF, MinPeakDistance, synchronous_frames);
        else
            warning('processRasterPlots n''a pas retourné de résultats valides.');
        end

        % Sauvegarde des résultats
        save(fullfile(directory, 'results_raster.mat'), ...
            'MinPeakDistance', 'sampling_rate', 'synchronous_frames', 'DF', ...
            'isort1', 'isort2', 'Sm', 'Raster', 'MAct', 'Acttmp2');

    catch ME
        % Affichage de l'erreur et assignation de NaN aux sorties
        warning('Erreur lors du traitement du raster pour %s: %s', directory, ME.message);
        isort1 = NaN; isort2 = NaN; Sm = NaN;
        Raster = NaN; MAct = NaN; Acttmp2 = NaN;
    end
end
