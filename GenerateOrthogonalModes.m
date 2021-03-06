function [modes, pc_scores] = GenerateOrthogonalModes(datadir, nlatent, outdir)
% GENERATE THE ORTHOGONAL CLINICAL MODES
%
% This script generate the clinical orthogonal modes from the combined LV
% surfaces at ED and ES based on 6 clinical indices.
%
%    [modes, pc_scores] = GenerateOrthogonalModes(datadir, nlatent, outputdir);
%
% Input:  - datadir is a directory where it contains:
%              'clinical_index.csv',
%              'surface_points_ED.csv', and
%              'surface_points_ES.csv' files.
%         - nlatent is the number of latent variables. It ranges from 1 to 10.
%         - outdir is a directory to store the generated modes and pc_scores 
%           to a file.
%           You can omit or set outputdir as an empty string to specify that there
%           is no external outputs are created.
%
% Output: - modes is N x M matrix, where N is the number of total surface
%           points and M is the number of clinical indices.
%         - pc_scores is P x M matrix, where P is the number of shapes in
%           the model, which is 2291.
%
% Author: Avan Suinesiaputra,
% Modified from: Xingyu Zhang, Pau Medrano-Gracia & Alistair Young
% University of Auckland - 2016

if( nargin < 3 ), outdir = ''; end

% read inputs
clinical_index_file = fullfile(datadir, 'clinical_index.csv');
if( ~exist(clinical_index_file, 'file') )
    error('Invalid data directory. No clinical_index.csv file is found.');
end

fprintf(1, 'Reading clinical index\n');
CI = importdata(clinical_index_file);
index_names = CI.textdata(1,2:end);  % get names from the header; column 1 is ignored
CI = CI.data;                        % get the numeric values

% the index order is important here
if( ~isequal(index_names, {'EDVI', 'Sphericity', 'EF', 'RWT', 'Conicity', 'LS'}) )
    error('ERROR: Invalid clinical index file.');
end

% get surface points at ED
pts_ED_file = fullfile(datadir,'surface_points_ED.csv');
if( ~exist(pts_ED_file, 'file') )
    error('Invalid data directory. No surface_points_ED.csv file is found.');
end

fprintf(1, 'Reading LV surface points at ED\n');
pts_ED = importdata(pts_ED_file);

% get surface points at ES
pts_ES_file = fullfile(datadir,'surface_points_ES.csv');
if( ~exist(pts_ES_file, 'file') )
    error('Invalid data directory. No surface_points_ES.csv file is found.');
end

fprintf(1, 'Reading LV surface points at ES\n');
pts_ES = importdata(pts_ES_file);

% combine ED & ES points into a single matrix
pts = [pts_ED pts_ES];

% calculate the mean shape and B0 vectors
mean_shape = mean(pts,1);
B0 = pts - repmat(mean_shape, size(pts,1),1);

clear('pts_ED', 'pts_ES');    % memory conservation

% check number of latent variables
if( nlatent<1 || nlatent>10 )
    error('ERROR: Number of latent variables must be between 1 and 10.');
end

% store modes, pc_scores
modes = zeros(size(pts,2), length(index_names));
pc_scores = zeros(size(pts,1), length(index_names));

% initial X
X = pts;

% run through all indices
tic;
for si=1:length(index_names)
    
    fprintf(1, 'STEP %d:\n', si);
    
    % calculate the mode
    fprintf(1, 'PLS regression with %d latent variables for %s\n', nlatent, index_names{si});
    % I don't need the rest, just the coefficients
    [~,~,~,~,BETA] = plsregress(X,CI(:,si),nlatent);
    
    % get the coefficients, excluding the intercept (first row)
    modes(:,si) = BETA(2:end,:);
    
    % normalize
    modes(:,si) = modes(:,si) ./ norm(modes(:,si));

    % calculate scores
    pc_scores(:,si) = pts * modes(:,si);
    
    % remove this mode and the previous mode(s) from the data
    B1 = zeros(size(B0));
    for i=1:si
        B1 = B1 + ( (B0 * modes(:,i)) * modes(:,i)' );
    end
    
    % now X is B0 - B1
    X = B0 - B1;
    
    toc;
    
end

if( ~isempty(outdir) )
    
    % create outputs
    fout_mode = fullfile(outdir, sprintf('ortho-modes-nlatent_%d.csv', nlatent));
    fprintf(1, 'Writing modes to %s\n', fout_mode);
    dlmwrite(fout_mode, modes, ',');

    fout_pcs = fullfile(outdir, sprintf('ortho-pcscores-nlatent_%d.csv', nlatent));
    fprintf(1, 'Writing principal scores to %s\n', fout_pcs);
    dlmwrite(fout_pcs, pc_scores, ',');

end

end


% ---- AUX FILES ----

function fname = ask_input_file(folder, filename)

    % loop until the expected file exists or it's empty string (user cancels)
    fname = fullfile(folder,filename);
    while( ~exist(fname,'file') && ~isempty(fname) )
        
        fprintf(2, 'PLEASE SELECT A DIRECTORY THAT CONTAINS ''%s''.\n', filename);
        d = folder;
        
        % ask user the directory that contains filename
        d = uigetdir(d, sprintf('Select folder that contains ''%s''', filename));
        if( ~ischar(d) )
            fname = '';
            break;
        end
        
        fname = fullfile(d,filename);
        
    end
    
end
