## DSC Resource Kit

Currently [DSC Resource Kit Wave 10](https://gallery.technet.microsoft.com/DSC-Resource-Kit-All-c449312d) (released Feb 13, 2015, updated April 01, 2015)

## Notes

Be aware that the composite resources in this resource kit are not automaticaly discovered from the puppet dsc module at types build time.
If you'd like to generate a puppet type for them, you have to manually create a xxx.schema.mof file next to the xxx.schema.psm1 file.

Look at the xWordPress/DscResources/xIisWordPressSite/xIisWordPressSite.schema.mof as an example.


