function varargout = process_mia_export_db( varargin )
% PROCESS_EXAMPLE_CUSTOMAVG: Example file that reads all the data files in input, and saves the average.

% @=============================================================================
% This software is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2013 Brainstorm by the University of Southern California
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Anne-Sophie Dubarry 2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Export data to MIA database';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'SEEG';
    sProcess.Index       = 1000;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % File selection options
    SelectOptions = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'MIA database...', ...               % Window title
        'ExportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'dirs', ...                          % Selection mode: {files,dirs,files_and_dirs}
       };                     
   % Option: MIA database folder
    sProcess.options.mia_db.Comment = 'MIA databas folder:';
    sProcess.options.mia_db.Type    = 'filename';
    sProcess.options.mia_db.Value   = SelectOptions;
    
    % Options: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'SEEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    sProcess.options.sensortypes.Group   = 'input';
  
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list of files
    OutputFiles = {};
  
    % Get option values
    mia_db= sProcess.options.mia_db.Value{1};
    
    % ===== LOAD THE DATA =====
    % Read the first file in the list, to initialize the loop
    DataMat = in_bst(sInputs(1).FileName, [], 0);
    epochSize = size(DataMat.F);
    Time = DataMat.Time;
    % Initialize the load matrix: [Nchannels x Ntime x Nepochs]
    AllMat = zeros(epochSize(1), epochSize(2), length(sInputs));
    % Reading all the input files in a big matrix
    for i = 1:length(sInputs)
        % Read the file #i
        DataMat = in_bst(sInputs(i).FileName, [], 0);
        % Check the dimensions of the recordings matrix in this file
        if ~isequal(size(DataMat.F), epochSize)
            % Add an error message to the report
            bst_report('Error', sProcess, sInputs, 'One file has a different number of channels or a different number of time samples.');
            % Stop the process
            return;
        end
        % Add the current file in the big load matrix
        AllMat(:,:,i) = DataMat.F;
    end
    
    % ===== PROCESS =====
     
%     Get all unique subjects
    [uniqueSubj,I,J] = unique({sInputs.SubjectFile});
    iGroups = cell(1, length(uniqueSubj));
    for i = 1:length(uniqueSubj)
        iGroups{i} = find(J == i)';
        GroupNames{i} = sInputs(iGroups{i}(1)).SubjectName;
    end   
    
    % Create database folder if it does not exist 
    if ~exist(mia_db, 'file') ; mkdir(mia_db) ; end

    % Move all patient data files into one folder patient directory 
    for pp=1:length(GroupNames)
        
        pt_dir = fullfile(mia_db,GroupNames{pp}) ;
        
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iGroups{pp}(1)).ChannelFile);
   
        % Get channels we want to process
        if ~isempty(sProcess.options.sensortypes.Value)
            [iChannels, SensorComment] = channel_find(ChannelMat.Channel, sProcess.options.sensortypes.Value);
        else
            iChannels = 1:length(ChannelMat.Channel);
        end
                
        % No sensors: error
        if isempty(iChannels)
            Messages = 'No sensors are selected.';
            bst_report('Warning', sProcess, sInputs, Messages);
            return;
        end
       
        sDataIn = in_bst_data(sInputs(iGroups{pp}(1)).FileName);

        if exist(pt_dir) 
           error('Patient exist, please remove patient from MIA_db'); 
        else
            % Create Output name
            outname = fullfile(pt_dir,strcat(GroupNames{pp},'_signal_LFP'));
            flag_good_chan =sDataIn.ChannelFlag ==1 ; 
            
            % Get data and remove bad channels
            F = AllMat(flag_good_chan(iChannels),:,iGroups{pp}) ; 
            Favg = mean(AllMat(:,:,iGroups{pp}),3) ; 
            labels = {ChannelMat.Channel(flag_good_chan(iChannels)).Name}; 
            Time = DataMat.Time;
            
            %Create patient direcotry and save file
            mkdir(pt_dir);
            save(outname, 'Time', 'F' ,'labels','Favg') ;

        end 
    end
    
    % Launch MIA main GUI on the new created database
    mia(mia_db);
  end