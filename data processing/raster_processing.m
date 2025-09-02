function [isort1, isort2, Sm] = raster_processing(DF, path, ops)
    
    % Initialisation des sorties en cas d'erreur
    isort1 = [];
    isort1_blue = [];
    isort2 = [];
    Sm = [];

    try 
        % Vérification de la taille de DF
        if isempty(DF) || size(DF, 1) < 2 || size(DF, 2) < 2
            fprintf('DF est vide ou ses dimensions sont incorrectes pour: %s\n', path);
            return
        end
        
        % Vérification de la présence de ops
        if nargin < 3 || isempty(ops)
            ops = struct(); % Initialisation à une structure vide si non fourni
        end       
   
        % Process raster plots
        [isort1, isort2, Sm] = processRasterPlots(DF, ops);
        
        % Vérification des dimensions avant de passer à Sumactivity
        if ~isempty(isort1) && ~isempty(isort2)
            % Vérification de la cohérence des dimensions
            if size(DF, 1) ~= size(isort1, 1)
                error('Dimension mismatch: DF et isort1 doivent avoir le même nombre de lignes.');
            end
        end

    catch ME
        % Affichage de l'erreur et assignation de NaN aux sorties
        warning('Erreur lors du traitement du raster pour %s: %s', path, ME.message);
        isort1 = []; isort2 = NaN; Sm = NaN;
        Raster = NaN; MAct = NaN; Acttmp2 = NaN;
    end
end