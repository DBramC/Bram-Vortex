package com.christos_bramis.bram_vortex.routes;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.RouterFunctions;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

@Configuration
public class GatewayRoutes {

    @Bean
    public RouterFunction<ServerResponse> serviceRoutes(WebClient webClient) {    // Routing URLs to functional routes
        return RouterFunctions.route()
                .GET("/auth/**", request -> routeToService(request, "http://auth-service:8080", webClient))
                .GET("/users/**", request -> routeToService(request, "http://user-service:8080", webClient))
                .GET("/projects/**", request -> routeToService(request, "http://project-service:8080", webClient))
                .build();
    }

    private Mono<ServerResponse> routeToService(ServerRequest request, String serviceBaseUrl, WebClient webClient) {
        String path = request.uri().getPath();
        String query = request.uri().getQuery();
        String fullUri = serviceBaseUrl + path + (query != null ? "?" + query : "");

        return webClient.get()
                .uri(fullUri)
                .headers(headers -> headers.addAll(request.headers().asHttpHeaders()))
                .retrieve()
                .bodyToMono(String.class)
                .flatMap(body -> ServerResponse.ok().bodyValue(body));
    }


}
