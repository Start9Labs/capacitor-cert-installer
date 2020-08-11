package com.start9labs.cert;

import android.app.Activity;
import android.content.Intent;
import android.security.KeyChain;

import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

@NativePlugin
public class CertInstaller extends Plugin {

    @PluginMethod
    public void installCert(PluginCall call) {
        String value = call.getString("value");
        String name = call.getString("name");
        if (value == null) {
            call.error("value required");
            return;
        }

        Intent installIntent = KeyChain.createInstallIntent();
        installIntent.putExtra(KeyChain.EXTRA_CERTIFICATE, value.getBytes());
        if (name != null) {
            installIntent.putExtra(KeyChain.EXTRA_NAME, name);
        }
        startActivityForResult(call, installIntent, 0);
        call.success();
    }
}
