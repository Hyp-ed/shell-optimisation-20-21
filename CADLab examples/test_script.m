app = CADLab.CADLabInitializer.StartSolidWorks;
doc = app.NewDocument('sldprt');
prt = app.ActiveDoc;

doc.SaveAs('C:\Users\maksg\Documents\MATLAB\test2.SLDPRT', false, false)


%test = app.GetCurrentWorkingDirectory


%prt = app.OpenDoc('test.SLDPRT');


%app.CloseAllDocuments