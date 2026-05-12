package pl.eengine.signaturetool;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class SignatureToolApplication {
    public static void main(String[] args) {
        SpringApplication.run(SignatureToolApplication.class, args);
    }
}
