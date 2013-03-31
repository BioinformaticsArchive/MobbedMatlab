%% Set up parameters for timing eeglab sample data
hostName = 'localhost';
userName = 'postgres';
password = 'admin';
dbScript = 'mobbed.sql';
inDir = 'C:\Users\JCockfield\Desktop\MatData\EEGLABMat';
dataName = 'eeglab';
nameSpace = 'edu.utsa.cs.vislab';
modality = 'eeg';

%% No threading
fprintf('\n\nTiming with no thread pool\n');
threads = 0;
dbName = [dataName num2str(threads)];
timeParallel(dbName, hostName, userName, password, dbScript, ...
             inDir, nameSpace, dataName, modality, threads)

%% Threading with 1 thread
fprintf('\n\nTiming with 1 thread in pool\n');
threads = 1;
dbName = [dataName num2str(threads)];
matlabpool 1;
timeParallel(dbName, hostName, userName, password, dbScript, ...
             inDir, nameSpace, dataName, modality, threads)
matlabpool close

%% Threading with 2 threads
fprintf('\n\nTiming with 2 threads in pool\n');
threads = 2;
dbName = [dataName num2str(threads)];
matlabpool 2;
timeParallel(dbName, hostName, userName, password, dbScript, ...
             inDir, nameSpace, dataName, modality, threads)
matlabpool close 