load('SampleLatmixProfiles.mat');

i=1;
% for i=1:2:length(rhoProfile)
    im = InternalModes(rhoProfile{i},zProfile{i},zProfile{i},latitude,'method','finiteDifference');
    im.upperBoundary = UpperBoundary.rigidLid;
    im.lowerBoundary = LowerBoundary.none;
    %     im.ShowLowestModesAtWavenumber(0);
    im.ShowLowestModesAtFrequency(im.f0);
% end